#!/bin/bash
set -euo pipefail

echo "==> 1. Initializing and updating Corral dependencies..."
corral update

echo "==> 2. Compiling the C library wrapper dependency..."
make -C _corral/github_com_d_led_otp_pony_node

echo "==> 3. Compiling the Pony program with Corral package paths..."
corral run -- ponyc -d -b corral_demo

echo "==> 4. Preparing dynamic library links and files..."
cp _corral/github_com_d_led_otp_pony_node/libotp_pony_node_c.so .

if [ "$(uname)" = "Darwin" ]; then
    install_name_tool -change "@rpath/libotp_pony_node_c.so" "@loader_path/libotp_pony_node_c.so" corral_demo
fi

echo "==> 5. Running the Corral demo..."
./corral_demo
