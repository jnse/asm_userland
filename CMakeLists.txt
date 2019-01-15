cmake_minimum_required(VERSION 2.8.10)
project(asm_userland)

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

add_subdirectory(include)
add_subdirectory(src)
add_subdirectory(tests)

enable_testing()
add_test(malloc_test tests/malloc)
