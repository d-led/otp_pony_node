#!/usr/bin/env bash
# Builds the native shim and the Pony programs.
#
#   ./build.sh            release build
#   ./build.sh --debug    debug build
set -euo pipefail

build_type=Release

for argument in "$@"; do
  case "$argument" in
    -d|--debug) build_type=Debug ;;
    -h|--help)
      echo "usage: $0 [--debug]"
      exit 0
      ;;
    *)
      echo "unknown option: $argument" >&2
      exit 2
      ;;
  esac
done

build_pony() {
  local module=$1
  local binary=$2

  if [ "$build_type" = "Debug" ]; then
    ponyc "$module" -b "$binary" -d
  else
    ponyc "$module" -b "$binary"
  fi
}

cmake -S . -B build -DCMAKE_BUILD_TYPE="$build_type"
cmake --build build --parallel

echo "ponyc:"
ponyc --version

build_pony demo otp_pony_node
build_pony test otp_pony_node_test
