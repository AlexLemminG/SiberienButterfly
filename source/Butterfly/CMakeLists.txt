cmake_minimum_required(VERSION 3.1)

project(Butterfly)
link_directories("${CMAKE_BINARY_DIR}/lib")
link_directories("${Assimp_BINARY_DIR}/lib")#TODO assimp is a special boy for some reason


file(GLOB BUTTERFLY_SRC "*.*")
source_group("Butterfly" FILES ${BUTTERFLY_SRC})
add_library(Butterfly SHARED ${BUTTERFLY_SRC})

target_link_libraries(Butterfly SiberienEngine)

#TODO both SEngine and SiberienEngine exist and not interchangable is weird
target_include_directories(Butterfly PRIVATE "${SEngine_SOURCE_DIR}")
#TODO as list in engine cmakelists
# target_include_directories(Butterfly PRIVATE "${Optick_SOURCE_DIR}/src")
# target_include_directories(Butterfly PRIVATE "${SiberienEngine_SOURCE_DIR}/libs/mathfu/include")
# target_include_directories(Butterfly PRIVATE "${BULLET_PHYSICS_SOURCE_DIR}/src")
# target_include_directories(Butterfly PRIVATE "${bgfx_SOURCE_DIR}/../../../../../bgfx/include")


# get_cmake_property(_variableNames VARIABLES)
# list (SORT _variableNames)
# foreach (_variableName ${_variableNames})
    # message(STATUS "${_variableName}=${${_variableName}}")
# endforeach()

