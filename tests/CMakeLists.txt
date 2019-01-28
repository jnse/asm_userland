add_compile_options(-O0 -F dwarf -g -I${CMAKE_SOURCE_DIR}/include/ -I${CMAKE_SOURCE_DIR}/src/common/)
add_executable(malloc_test malloc/malloc_test.asm)
set_target_properties(malloc_test PROPERTIES LINKER_LANGUAGE NASM)
