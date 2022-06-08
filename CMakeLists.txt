cmake_minimum_required(VERSION 3.1)


set(CMAKE_BUILD_TYPE "Debug")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_definitions(-DUNICODE)
if (MSVC)
    add_definitions("/MP")
endif()

add_subdirectory(engine/source)
add_subdirectory(source)