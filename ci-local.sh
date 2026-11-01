#!/usr/bin/env bash
# Runs the Linux job from .github/workflows/ci.yml in a container: the same
# toolchain and the same commands, in the same order.
#
# Two things a container on this machine cannot reproduce: the macOS job, and
# a native x86_64 run when the host is arm64.  Those still need the runner.
set -euo pipefail

image=otp-pony-node:ci

echo "==> toolchain image, and ./build.sh inside it"
docker build -t "$image" .

echo "==> ./test.sh"
docker run --rm "$image" bash -lc "./test.sh"

echo "==> ./integration.sh"
docker run --rm "$image" bash -lc "./integration.sh"
