cmake_minimum_required(VERSION 3.1)

project(Butterfly LANGUAGES CXX)

file(GLOB BUTTERFLY_SRC "*.*")
source_group("Butterfly" FILES ${BUTTERFLY_SRC})
add_library(Butterfly SHARED ${BUTTERFLY_SRC})

target_link_libraries(Butterfly PRIVATE SiberienEngine)