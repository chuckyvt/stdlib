### Pre-process: .fpp -> .f90 via Fypp

# Create a list of the files to be preprocessed
set(fppFiles
    test_maps.fypp
)

fypp_f90("${fyppFlags}" "${fppFiles}" outFiles)

ADDTEST(chaining_maps)
ADDTEST(open_maps)
ADDTEST(maps)

# Freeing a map must not need stack space proportional to its size.
# On Unix-like systems, run under a 128 KiB stack so a recursive free fails.
add_executable(test_maps_free_stack test_maps_free_stack.f90)
target_link_libraries(test_maps_free_stack "${PROJECT_NAME}")
if(UNIX)
    add_test(NAME maps_free_stack
             COMMAND sh -c "ulimit -s 128 && exec \"$0\""
                     $<TARGET_FILE:test_maps_free_stack>)
else()
    add_test(NAME maps_free_stack
             COMMAND $<TARGET_FILE:test_maps_free_stack>)
endif()

