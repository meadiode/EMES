cmake_minimum_required(VERSION 3.13...3.27)

# pico-sdk: branch master; sha: f396d05f8252d4670d4ea05c8b7ac938ef0cd381

include(pico_sdk_import.cmake)

project(demo)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

if (PICO_SDK_VERSION_STRING VERSION_LESS "1.3.0")
    message(FATAL_ERROR "Raspberry Pi Pico SDK version 1.3.0 (or later) required. Your version is ${PICO_SDK_VERSION_STRING}")
endif()


set (LIBS
        pico_stdlib
        pico_multicore
        cmsis_core
        hardware_pwm
        hardware_i2c
)

add_executable(demo demo.c)

target_include_directories(demo PRIVATE ${CMAKE_CURRENT_LIST_DIR})
target_link_libraries(demo ${LIBS})
pico_add_extra_outputs(demo)
