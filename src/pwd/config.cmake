set(SOURCE_FILES ${CMAKE_SOURCE_DIR}/src/pwd/pwd.asm)
add_executable(pwd ${SOURCE_FILES})
set_target_properties(pwd PROPERTIES LINKER_LANGUAGE NASM)
add_dependencies(pwd linux_syscalls)
