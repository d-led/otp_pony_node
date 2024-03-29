#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

case "$(uname)" in
  Darwin)
    os="macosx"
  ;;

  Linux)
    os="linux"
    export PATH=/root/.local/share/ponyup/bin:$PATH
  ;;

  *)
    echo $"unknown OS. Stopping"
    exit 1 
esac

./premake/${os}/premake5 gmake

# compile the C part
rm -f libotp_pony_node_c.so
make -C build/${os}/gmake config=debug

echo "pony"
ponyc --version

# compile the Pony part
ponyc demo -d -b otp_pony_node
ponyc test -d -b otp_pony_node_test

if [ "$os" == "macosx" ]; then
    install_name_tool -change "@rpath/libotp_pony_node_c.so" "@loader_path/libotp_pony_node_c.so" otp_pony_node
    install_name_tool -change "@rpath/libotp_pony_node_c.so" "@loader_path/libotp_pony_node_c.so" otp_pony_node_test
fi
