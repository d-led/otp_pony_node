#!/bin/bash
# Demonstrates using otp_pony_node as a Corral dependency.
set -euo pipefail

echo "==> 1. Fetching the dependency"
corral fetch

echo "==> 2. Building the native shim inside the dependency"
make -C _corral/github_com_d_led_otp_pony_node

echo "==> 3. Compiling the demo"
corral run -- ponyc -b corral_demo

echo "==> 4. Running the demo"
./corral_demo
