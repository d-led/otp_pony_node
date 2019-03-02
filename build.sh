#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

case "$(uname)" in
  Darwin)
    os="macosx"
  ;;

  Linux)
    os="linux"
  ;;

  *)
    echo $"unknown OS. Stopping"
    exit 1 
esac

./premake/${os}/premake5 gmake

# compile the C part
rm -f libotp_pony_node_c.so
make -C build/${os}/gmake config=debug

# compile the Pony part
ponyc -d -b otp_pony_node

if [ "$os" == "macosx" ]; then
    install_name_tool -change "@rpath/libotp_pony_node_c.so" "@loader_path/libotp_pony_node_c.so" otp_pony_node
fi
