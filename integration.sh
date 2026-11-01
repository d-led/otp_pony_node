#!/usr/bin/env bash
# Talks to a real Elixir node in both directions: the demo script sends
# messages and the Pony node answers them, then the Pony node publishes itself
# and the Elixir node calls it in.  Fails when either exchange does not happen.
set -euo pipefail

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
  rm -f "$outbound_log" "$pony_log"
}
trap cleanup EXIT

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

wait_for_the_node_to_listen() {
  local attempts=50
  while [ "$attempts" -gt 0 ]; do
    if grep -q " listening on port " "$pony_log"; then return 0; fi
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

if ! elixir --sname caller@localhost --cookie secretcookie incoming.exs "$pony_node"; then
  echo "the Elixir node could not call the Pony node:" >&2
  cat "$pony_log" >&2
  exit 1
fi

echo "the Elixir node called the Pony node"
