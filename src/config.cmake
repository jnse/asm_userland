set(CMAKE_NASM_LINK_EXECUTABLE "ld <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
set(CAN_USE_ASSEMBLER TRUE)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_ASM_NASM_OBJECT_FORMAT macho64)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -macosx_version_min 10.13")
    set(CMAKE_ASM_NASM_FLAGS "-DMACOS")
    link_libraries(System)
endif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

if (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64)
endif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")

enable_language(ASM_NASM)
add_compile_options(-g -I${CMAKE_SOURCE_DIR}/include/ -I${CMAKE_SOURCE_DIR}/src/common/)
set(SYSCALL_FILE "${CMAKE_SOURCE_DIR}/include/syscalls.asm")
add_custom_target(linux_syscalls ${CMAKE_SOURCE_DIR}/scripts/get_syscalls.sh ${SYSCALL_FILE})

include("${CMAKE_SOURCE_DIR}/src/true/config.cmake")
include("${CMAKE_SOURCE_DIR}/src/false/config.cmake")
include("${CMAKE_SOURCE_DIR}/src/pwd/config.cmake")
include("${CMAKE_SOURCE_DIR}/src/env/config.cmake")
