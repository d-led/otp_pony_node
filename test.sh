#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

./otp_pony_node_test

./demo_exs.sh &

sleep 2

./otp_pony_node
