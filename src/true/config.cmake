set(SOURCE_FILES ${CMAKE_SOURCE_DIR}/src/true/true.asm)
add_executable(true ${SOURCE_FILES})
set_target_properties(true PROPERTIES LINKER_LANGUAGE NASM)
