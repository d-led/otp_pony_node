#!/usr/bin/env bash
# Runs the unit tests.  Nothing here needs an Erlang node running, but the
# reachable tests publish one of their own, which talks to epmd.
set -euo pipefail

# shellcheck source=epmd.sh
. ./epmd.sh
ensure_epmd

./otp_pony_node_test
