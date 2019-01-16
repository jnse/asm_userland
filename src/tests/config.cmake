enable_testing()
add_test(malloc malloc)
add_executable(malloc malloc/malloc.asm)
set_target_properties(malloc PROPERTIES LINKER_LANGUAGE NASM)
add_dependencies(malloc linux_syscalls)


