#!/usr/bin/env bash
# Runs the unit tests.  Nothing here needs an Erlang node running, but the
# reachable tests publish one of their own, which talks to epmd.  Erlang starts
# epmd for itself; a machine that only has the library starts it here.
set -euo pipefail

if command -v epmd >/dev/null 2>&1; then
  epmd -daemon 2>/dev/null || true
fi

./otp_pony_node_test
