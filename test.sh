#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

./demo_exs.sh &

sleep 2

./otp_pony_node
