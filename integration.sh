#!/usr/bin/env bash
# Talks to a real Elixir node in both directions: the demo script sends
# messages and the Pony node answers them, then the Pony node publishes itself
# and the Elixir node calls it in.  Fails when either exchange does not happen.
#
# This is where a call in is proved, because the other side is another program
# with a node of its own; the unit tests do not put two of this library's
# nodes in one process against each other.
set -euo pipefail

# shellcheck source=epmd.sh
. ./epmd.sh
ensure_epmd

port=47_002
outbound_log=$(mktemp "${TMPDIR:-/tmp}/otp_pony_node_demo.XXXXXX")
pony_log=$(mktemp "${TMPDIR:-/tmp}/otp_pony_node_serving.XXXXXX")

elixir_pid=""
pony_pid=""

cleanup() {
  for pid in "$elixir_pid" "$pony_pid"; do
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done

  # epmd hears that a node has gone a moment after its process ends, and it
  # takes the name away by its name -- the one a run started in between has
  # already published.  Both demo nodes are called `pony` something, so the
  # next run starts once epmd has forgotten them.
  wait_for_epmd_to_forget_the_demo

  rm -f "$outbound_log" "$pony_log"
}
trap cleanup EXIT

wait_for_epmd_to_forget_the_demo() {
  if ! command -v epmd >/dev/null 2>&1; then
    return 0
  fi

  local tries=0
  while epmd -names 2>/dev/null | grep -q '^name pony'; do
    tries=$((tries + 1))
    if [ "$tries" -ge 50 ]; then
      return 0
    fi
    sleep 0.1
  done
}

# epmd knows a node as soon as it has registered, which is the moment the other
# side can call it -- earlier than the node says so itself, and without
# waiting for a sleep to be long enough on a machine under load.
wait_for_epmd_to_know() {
  local name=$1
  local tries=0

  while [ "$tries" -lt 150 ]; do
    if epmd -names 2>/dev/null | grep -q "^name $name "; then
      return 0
    fi
    sleep 0.2
    tries=$((tries + 1))
  done
  return 1
}

# The host part of a node name, as the library writes it: the machine's host
# name without the domain it may carry, lower case.
short_host() {
  hostname | tr '[:upper:]' '[:lower:]' | cut -d. -f1
}

# The Pony node calls out, and answers.
elixir --sname demo@localhost --cookie secretcookie demo.exs > "$outbound_log" 2>&1 &
elixir_pid=$!

if ! wait_for_epmd_to_know demo; then
  echo "the Elixir node did not start:" >&2
  cat "$outbound_log" >&2
  exit 1
fi

./otp_pony_node

if ! grep -q "Elixir: received: {:reply," "$outbound_log"; then
  echo "the Pony node never answered:" >&2
  cat "$outbound_log" >&2
  exit 1
fi

echo "the Pony node answered the Elixir node"

# The Pony node is called in, and answers.  epmd is asked whether the node is
# there, which its own report cannot be relied on for: what it prints is
# flushed when it has published, but a machine under load takes a while to get
# that far, and the report is only read once epmd says it is listening.
./otp_pony_node --listen "$port" > "$pony_log" 2>&1 &
pony_pid=$!

wait_for_epmd_to_know_the_node() {
  local attempts=600
  while [ "$attempts" -gt 0 ]; do
    if epmd -names 2>/dev/null | grep -q '^name pony_server '; then
      return 0
    fi

    if ! kill -0 "$pony_pid" 2>/dev/null; then
      echo "the Pony node stopped before it published itself:" >&2
      cat "$pony_log" >&2
      exit 1
    fi

    sleep 0.2
    attempts=$((attempts - 1))
  done
  return 1
}

if ! wait_for_epmd_to_know_the_node; then
  echo "the Pony node did not publish itself:" >&2
  cat "$pony_log" >&2
  exit 1
fi

pony_node=$(sed -n 's/^Pony: \(.*\) listening on port .*$/\1/p' "$pony_log" | head -1)
if [ -z "$pony_node" ]; then
  pony_node="pony_server@$(short_host)"
fi
echo "the Pony node is $pony_node"

# The caller is named on the host the Pony node named itself on: two ends
# named differently do not talk.
caller_flags=(--sname "caller@${pony_node#*@}")

if ! elixir "${caller_flags[@]}" --cookie secretcookie incoming.exs "$pony_node"; then
  echo "the Elixir node could not call the Pony node:" >&2
  cat "$pony_log" >&2
  exit 1
fi

echo "the Elixir node called the Pony node"

# A quiet connection.  The Erlang side polls a connection it has nothing to say
# on and drops the other end when the polls are not answered; a node answers
# them while it is reading.  The caller is given a tick time it cannot ignore,
# and says nothing for more than twice as long before it speaks.
silenced_caller_flags=(--sname "quiet@${pony_node#*@}" --erl "-kernel net_ticktime 4")

if ! elixir "${silenced_caller_flags[@]}" --cookie secretcookie incoming.exs \
  "$pony_node" 9000; then
  echo "the Pony node was dropped while it was quiet:" >&2
  cat "$pony_log" >&2
  exit 1
fi

echo "the Pony node stayed reachable through a silence"
