# The shell's native QML module, "Nafeel": what QML alone can't do on umbriel.
#
#   WindowThumb   a live picture of one window (ext-image-copy-capture), only
#                 while it's visible, new frames only when the window changes
#   Keyboard      the modifiers held right now (the switcher's Alt release)
#   BlobGroup, BlobRect, BlobInvertedRect
#                 the frame as SDF blobs that merge (Ryoku's engine, GPL-3.0)
#
# Build: ./build.sh  ->  build/qml/Nafeel (the supervisor adds build/qml to
# QML_IMPORT_PATH).
cmake_minimum_required(VERSION 3.21)
project(nafeel-native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Quick ShaderTools)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_get_variable(WL_PROTOCOLS wayland-protocols pkgdatadir)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(protocols
    ext-foreign-toplevel-list
    ext-image-capture-source
    ext-image-copy-capture)
set(protocol_sources)
foreach(p IN LISTS protocols)
    set(xml "${WL_PROTOCOLS}/staging/${p}/${p}-v1.xml")
    add_custom_command(
        OUTPUT ${p}-v1-client-protocol.h ${p}-v1-protocol.c
        COMMAND ${WAYLAND_SCANNER} client-header ${xml} ${p}-v1-client-protocol.h
        COMMAND ${WAYLAND_SCANNER} private-code ${xml} ${p}-v1-protocol.c
        DEPENDS ${xml})
    list(APPEND protocol_sources
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-v1-client-protocol.h
        ${CMAKE_CURRENT_BINARY_DIR}/${p}-v1-protocol.c)
endforeach()

qt_policy(SET QTP0001 NEW)
qt_add_library(nafeelnative SHARED)
qt_add_qml_module(nafeelnative
    URI Nafeel
    VERSION 1.0
    PLUGIN_TARGET nafeelnative
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME NafeelPlugin
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Nafeel
    SOURCES
        src/plugin.cpp
        src/capture.h src/capture.cpp
        src/windowthumb.h src/windowthumb.cpp
        src/keyboard.h
        src/blobgroup.hpp src/blobgroup.cpp
        src/blobshape.hpp src/blobshape.cpp
        src/blobrect.hpp src/blobrect.cpp
        src/blobinvertedrect.hpp src/blobinvertedrect.cpp
        src/blobmaterial.hpp src/blobmaterial.cpp)
target_sources(nafeelnative PRIVATE ${protocol_sources})
target_include_directories(nafeelnative PRIVATE ${CMAKE_CURRENT_BINARY_DIR} src)
target_link_libraries(nafeelnative PRIVATE Qt6::Gui Qt6::Quick PkgConfig::WAYLAND)

qt_add_shaders(nafeelnative "blob_shaders"
    BATCHABLE
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/blob.vert
        shaders/blob.frag)
