set(SYSCALL_FILE "${CMAKE_SOURCE_DIR}/include/syscalls.asm")
add_custom_target(linux_syscalls ${CMAKE_SOURCE_DIR}/scripts/get_syscalls.sh ${SYSCALL_FILE})
