# Thin wrapper so that `make -C <this directory>` builds the native shim the
# way Corral consumers expect.  CMake is the build system proper; see
# CMakeLists.txt and CMakePresets.json.
#
#   make                 release build
#   make CONFIG=Debug    debug build
#   make test            build, then run the unit tests

CONFIG ?= Release

.PHONY: all native test clean

all: native

native:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=$(CONFIG)
	cmake --build build --parallel

test:
	./build.sh
	./test.sh

clean:
	rm -rf build build-debug build-zig build-zig-debug
	rm -f libotp_pony_node_c.a libotp_pony_node_c.so libotp_pony_node_c.dylib
