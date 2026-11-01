# Use zig as the C compiler: one toolchain on every platform, no dependency on
# a system clang/gcc.  Configure with -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/zig.cmake
# (or use the `zig` preset).

find_program(ZIG_EXECUTABLE NAMES zig)
if(NOT ZIG_EXECUTABLE)
    message(FATAL_ERROR "zig was not found on PATH")
endif()

set(CMAKE_C_COMPILER "${ZIG_EXECUTABLE}")
set(CMAKE_C_COMPILER_ARG1 "cc")

set(CMAKE_C_COMPILER_ID_RUN TRUE)
set(CMAKE_C_COMPILER_ID "Clang")
set(CMAKE_C_COMPILER_FRONTEND_VARIANT "GNU")
