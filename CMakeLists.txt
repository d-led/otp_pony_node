cmake_minimum_required(VERSION 3.20)

project(otp_pony_node_c
    VERSION 0.2.0
    DESCRIPTION "C shim over OTP's ei library, built for the Pony otp_pony_node package"
    HOMEPAGE_URL "https://github.com/d-led/otp_pony_node"
    LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

option(OPN_WERROR "Treat compiler warnings as errors" OFF)
set(OPN_ARTIFACT_DIR "${PROJECT_SOURCE_DIR}" CACHE PATH
    "Where the finished libotp_pony_node_c archive is written; must be on the Pony package search path")

# Locate erl_interface
# `ei` is the only part of erl_interface left in modern OTP and it is shipped
# as a static archive, so the shim carries it along: Pony consumers link one
# file and need nothing but the resulting executable at run time.
set(OPN_EI_DIR "" CACHE PATH
    "erl_interface installation directory (contains include/ei.h and lib/libei.a)")

if(NOT OPN_EI_DIR)
    find_program(OPN_ERL_EXECUTABLE erl DOC "Erlang runtime, used to locate erl_interface")
    if(OPN_ERL_EXECUTABLE)
        execute_process(
            COMMAND ${OPN_ERL_EXECUTABLE} -noshell -eval
                    "io:format(\"~s\", [code:lib_dir(erl_interface)]), halt()."
            OUTPUT_VARIABLE _opn_candidate
            RESULT_VARIABLE _opn_result
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(_opn_result EQUAL 0 AND EXISTS "${_opn_candidate}/include/ei.h")
            set(OPN_EI_DIR "${_opn_candidate}")
        endif()
    endif()
endif()

find_path(OPN_EI_INCLUDE_DIR ei.h
    HINTS "${OPN_EI_DIR}/include")

# The archive, not the shared library: a distribution that ships both would
# otherwise have find_library pick the shared one, and merging needs members.
find_file(OPN_EI_ARCHIVE NAMES libei.a libei.lib
    HINTS "${OPN_EI_DIR}/lib")
if(OPN_EI_ARCHIVE)
    set(OPN_EI_LIBRARY "${OPN_EI_ARCHIVE}")
else()
    find_library(OPN_EI_LIBRARY NAMES ei
        HINTS "${OPN_EI_DIR}/lib")
endif()

if(NOT OPN_EI_INCLUDE_DIR OR NOT OPN_EI_LIBRARY)
    message(FATAL_ERROR
        "erl_interface (ei.h and libei.a) was not found.\n"
        "Install Erlang/OTP and make sure `erl` is on PATH, or configure with\n"
        "  -DOPN_EI_DIR=<path to .../lib/erlang/lib/erl_interface-X.Y>")
endif()

get_filename_component(OPN_EI_LIBRARY_NAME "${OPN_EI_LIBRARY}" NAME)
if(NOT OPN_EI_LIBRARY_NAME MATCHES "^libei\\.(a|lib)$")
    message(FATAL_ERROR
        "erl_interface must provide the static archive libei.a, found: ${OPN_EI_LIBRARY}\n"
        "The shim links ei statically so that Pony programs need no runtime library path.")
endif()

message(STATUS "erl_interface headers: ${OPN_EI_INCLUDE_DIR}")
message(STATUS "erl_interface archive: ${OPN_EI_LIBRARY}")

# The shim
add_library(otp_pony_node_c STATIC src/otp_pony_node_c/otp_pony_node_c.c)

target_include_directories(otp_pony_node_c PRIVATE "${OPN_EI_INCLUDE_DIR}")
target_compile_definitions(otp_pony_node_c PRIVATE _REENTRANT)

if(WIN32)
    # ei.h selects its 64 bit integer types on __WIN32__
    target_compile_definitions(otp_pony_node_c PRIVATE __WIN32__)
endif()

if(MSVC)
    target_compile_options(otp_pony_node_c PRIVATE /W4)
    if(OPN_WERROR)
        target_compile_options(otp_pony_node_c PRIVATE /WX)
    endif()
else()
    target_compile_options(otp_pony_node_c PRIVATE -Wall -Wextra)
    if(OPN_WERROR)
        target_compile_options(otp_pony_node_c PRIVATE -Werror)
    endif()
endif()

set_target_properties(otp_pony_node_c PROPERTIES
    OUTPUT_NAME otp_pony_node_c
    ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")

# Fold ei into the shim: one archive, no runtime library search path
set(OPN_MERGED_ARCHIVE
    "${OPN_ARTIFACT_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}otp_pony_node_c${CMAKE_STATIC_LIBRARY_SUFFIX}")

add_custom_command(
    OUTPUT "${OPN_MERGED_ARCHIVE}"
    COMMAND ${CMAKE_COMMAND}
            -DOUTPUT=${OPN_MERGED_ARCHIVE}
            -DLIBRARIES=$<TARGET_FILE:otp_pony_node_c>\;${OPN_EI_LIBRARY}
            -DWORK_DIR=${PROJECT_BINARY_DIR}/merge
            -DAR=${CMAKE_AR}
            -P "${PROJECT_SOURCE_DIR}/cmake/MergeStaticLibraries.cmake"
    DEPENDS otp_pony_node_c "${OPN_EI_LIBRARY}"
            "${PROJECT_SOURCE_DIR}/cmake/MergeStaticLibraries.cmake"
    COMMENT "Merging libei into libotp_pony_node_c"
    VERBATIM)

add_custom_target(otp_pony_node_c_merged ALL DEPENDS "${OPN_MERGED_ARCHIVE}")

install(FILES "${OPN_MERGED_ARCHIVE}" TYPE LIB)
