#add_compile_options(-g -O0 -I${CMAKE_SOURCE_DIR}/include/ -I${CMAKE_SOURCE_DIR}/src/common/)
add_compile_options(-Ox -I${CMAKE_SOURCE_DIR}/include/ -I${CMAKE_SOURCE_DIR}/src/common/)

add_subdirectory(true)
add_subdirectory(false)
add_subdirectory(pwd)
add_subdirectory(env)
