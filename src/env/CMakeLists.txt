set(SOURCE_FILES ${CMAKE_SOURCE_DIR}/src/env/env.asm)
add_executable(env ${SOURCE_FILES})
set_target_properties(env PROPERTIES LINKER_LANGUAGE NASM)
add_dependencies(env linux_syscalls)
