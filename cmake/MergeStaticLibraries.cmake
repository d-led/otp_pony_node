# Merges static libraries into a single archive.
#
# Invoked from CMakeLists.txt with:
#   OUTPUT     destination archive path
#   LIBRARIES  semicolon separated list of archives, in link order
#   WORK_DIR   scratch directory for the extracted objects
#   AR         the archiver (ar, or lib.exe on Windows)

if(WIN32)
    # lib.exe merges archives directly and keeps their members in order.
    execute_process(
        COMMAND "${AR}" /NOLOGO "/OUT:${OUTPUT}" ${LIBRARIES}
        RESULT_VARIABLE _merge_result)
else()
    file(REMOVE_RECURSE "${WORK_DIR}")
    file(MAKE_DIRECTORY "${WORK_DIR}")

    foreach(_library IN LISTS LIBRARIES)
        execute_process(
            COMMAND "${AR}" x "${_library}"
            WORKING_DIRECTORY "${WORK_DIR}"
            RESULT_VARIABLE _merge_result)
        if(NOT _merge_result EQUAL 0)
            message(FATAL_ERROR "Could not extract ${_library}")
        endif()
    endforeach()

    # BSD ar writes an index member into the working directory; it must not
    # become a member of the merged archive.  GNU ar does not, so this is
    # simply empty there.
    file(GLOB _symdefs "${WORK_DIR}/__.SYMDEF*")
    if(_symdefs)
        file(REMOVE ${_symdefs})
    endif()

    file(GLOB _objects "${WORK_DIR}/*.o" "${WORK_DIR}/*.obj")
    list(LENGTH _objects _object_count)
    if(_object_count EQUAL 0)
        message(FATAL_ERROR "No object files were extracted from ${LIBRARIES}")
    endif()

    file(REMOVE "${OUTPUT}")
    execute_process(
        COMMAND "${AR}" rcs "${OUTPUT}" ${_objects}
        WORKING_DIRECTORY "${WORK_DIR}"
        RESULT_VARIABLE _merge_result)
endif()

if(NOT _merge_result EQUAL 0)
    message(FATAL_ERROR "Could not create ${OUTPUT}")
endif()
