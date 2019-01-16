
add_executable(malloc_bench malloc/malloc_benchmark.asm)
set_target_properties(malloc_bench PROPERTIES LINKER_LANGUAGE NASM)
target_compile_options(malloc_bench PUBLIC -Ox -I${CMAKE_SOURCE_DIR}/include/ -I${CMAKE_SOURCE_DIR}/src/common/)

add_executable(malloc_baseline malloc/baseline.c)
target_compile_options(malloc_baseline PUBLIC "-O3")

add_custom_target(bench COMMAND ${CMAKE_SOURCE_DIR}/bench/benchmark.sh ${CMAKE_CURRENT_BINARY_DIR})
add_dependencies(bench malloc_baseline)
add_dependencies(bench malloc_bench)
