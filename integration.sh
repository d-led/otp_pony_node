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

# The Pony node calls out, and answers.
elixir --sname demo@localhost --cookie secretcookie demo.exs > "$outbound_log" 2>&1 &
elixir_pid=$!

sleep 2
./otp_pony_node

if ! grep -q "Elixir: received: {:reply," "$outbound_log"; then
  echo "the Pony node never answered:" >&2
  cat "$outbound_log" >&2
  exit 1
fi

echo "the Pony node answered the Elixir node"

# The Pony node is called in, and answers.  The name it published is read back
# from its own report, since the case of a host name is spelled one way by the
# node and another by whoever looks it up.
./otp_pony_node --listen "$port" > "$pony_log" 2>&1 &
pony_pid=$!

# The node reports that it listens once it is registered, which on a busy
# machine can take longer than a node starting up does.
wait_for_the_node_to_listen() {
  local attempts=300
  while [ "$attempts" -gt 0 ]; do
    if grep -q " listening on port " "$pony_log"; then return 0; fi

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

if ! wait_for_the_node_to_listen; then
  echo "the Pony node did not publish itself:" >&2
  cat "$pony_log" >&2
  exit 1
fi

pony_node=$(sed -n 's/^Pony: \(.*\) listening on port .*$/\1/p' "$pony_log" | head -1)
echo "the Pony node is $pony_node"

# The caller is named on the host the Pony node named itself on.  A node of
# Erlang's own with a short name is only allowed to talk to hosts it can name
# without a domain, and on a machine whose host name carries one the two ends
# then disagree about what the other is called.
caller_node="caller@${pony_node#*@}"

if ! elixir --sname "$caller_node" --cookie secretcookie incoming.exs "$pony_node"; then
  echo "the Elixir node could not call the Pony node:" >&2
  cat "$pony_log" >&2
  exit 1
fi

echo "the Elixir node called the Pony node"
