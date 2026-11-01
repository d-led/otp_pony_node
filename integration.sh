#!/usr/bin/env bash
# Talks to a real Elixir node: the demo script sends messages and the Pony node
# answers them.  Fails when the exchange does not happen.
set -euo pipefail

log=$(mktemp "${TMPDIR:-/tmp}/otp_pony_node_demo.XXXXXX")

elixir --sname demo@localhost --cookie secretcookie demo.exs > "$log" 2>&1 &
elixir_pid=$!

cleanup() {
  kill "$elixir_pid" 2>/dev/null || true
  wait "$elixir_pid" 2>/dev/null || true
  rm -f "$log"
}
trap cleanup EXIT

sleep 2
./otp_pony_node

if ! grep -q "Elixir: received: {:reply," "$log"; then
  echo "the Pony node never answered:" >&2
  cat "$log" >&2
  exit 1
fi

echo "the Pony node answered the Elixir node"
