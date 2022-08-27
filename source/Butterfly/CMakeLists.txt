cmake_minimum_required(VERSION 3.6)

project(Butterfly LANGUAGES CXX)

file(GLOB BUTTERFLY_SRC "*.*")
source_group("Butterfly" FILES ${BUTTERFLY_SRC})
add_library(Butterfly SHARED ${BUTTERFLY_SRC})

target_link_libraries(Butterfly PRIVATE SiberienEngine)

set_property(TARGET Butterfly PROPERTY VS_DEBUGGER_COMMAND "$(TargetDir)/SiberienEngine.exe")
set_property(TARGET Butterfly PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT Butterfly)