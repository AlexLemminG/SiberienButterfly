cmake_minimum_required(VERSION 3.6)

project(Butterfly LANGUAGES CXX)

set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fvisibility=hidden")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fvisibility=hidden")

file(GLOB BUTTERFLY_SRC "*.*")
source_group("Butterfly" FILES ${BUTTERFLY_SRC})
add_library(Butterfly SHARED ${BUTTERFLY_SRC})
message(${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
set_target_properties(Butterfly PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

#TODO sorry future me, i'm too tired to figure out how to do it properly now
# add_definitions(-DRYML_SHARED)
# add_definitions(-DC4CORE_SHARED)

target_link_libraries(Butterfly PRIVATE SiberienEngine)

set_property(TARGET Butterfly PROPERTY VS_DEBUGGER_COMMAND "$(TargetDir)/SiberienEngine.exe")
set_property(TARGET Butterfly PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT Butterfly)
