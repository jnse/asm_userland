set(SOURCE_FILES ${CMAKE_SOURCE_DIR}/src/false/false.asm)
add_executable(false ${SOURCE_FILES})
set_target_properties(false PROPERTIES LINKER_LANGUAGE NASM)
