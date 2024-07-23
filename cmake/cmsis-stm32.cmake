# SPDX-FileCopyrightText: 2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.25)

include(FetchContent)

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND NOT DEFINED ENV{CMAKE_TOOLCHAIN_FILE})
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/toolchains/gcc-arm-none-eabi.cmake")
endif()

function(cmsis_stm32_target target)
    if(TARGET _cmsis_stm32_target_${target})
        message(AUTHOR_WARNING "cmsis_stm32_target(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_cmsis_stm32_target_${target} INTERFACE)

    if(NOT TARGET ${target})
        message(FATAL_ERROR "Target ${target} not defined")
    endif()

    if(NOT DEFINED CMAKE_C_COMPILER_ID)
        message(FATAL_ERROR "Missing C compiler, please enable C language in your CMakeLists.txt.")
    endif()

    if(NOT DEFINED CMAKE_ASM_COMPILER_ID)
        message(FATAL_ERROR "Missing ASM compiler, please enable ASM language in CMake.")
    endif()

    if((NOT CMAKE_C_COMPILER_ID STREQUAL "GNU") OR (NOT CMAKE_ASM_COMPILER_ID STREQUAL "GNU"))
        message(FATAL_ERROR "Unsupported compiler, please use GCC (https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)")
    endif()

    set(one_value_args
        DEVICE
        INSTALL
        LINKER_SCRIPT
        SHOW_SIZE
        STLINK
        VERSION
    )

    set(multi_value_args
        ADDITIONAL_OUTPUTS
    )

    cmake_parse_arguments(target_arg "" "${one_value_args}" "${multi_value_args}" ${ARGN})

    if(NOT target_arg_DEVICE)
        message(FATAL_ERROR "DEVICE is required: a device identificator, as recognized by the ST CMSIS device headers (e.g. STM32F042x6)")
    endif()
    if(NOT target_arg_LINKER_SCRIPT)
        message(FATAL_ERROR "LINKER_SCRIPT is required: a ld linker script compatible with ST CMSIS startup scripts")
    endif()
    if(NOT target_arg_VERSION)
        message(FATAL_ERROR "VERSION is required: 'LATEST' or a release from https://github.com/rafaelmartins/cmsis-stm32/releases")
    endif()

    foreach(out ${target_arg_ADDITIONAL_OUTPUTS})
        string(TOUPPER "${out}" out)
        if(out STREQUAL "BIN")
            set(generate_bin ON)
        elseif(out STREQUAL "IHEX")
            set(generate_ihex ON)
        elseif(out STREQUAL "DFU")
            set(generate_dfu ON)
        elseif(out STREQUAL "MAP")
            set(generate_map ON)
        elseif(out STREQUAL "S19")
            set(generate_s19 ON)
        else()
            message(FATAL_ERROR "Invalid ADDITIONAL_OUTPUT: ${out}")
        endif()
    endforeach()

    string(TOUPPER "${target}" target_upper)
    set(CMSIS_STM32_INDEX_${target_upper}
        "${CMSIS_STM32_INDEX_${target_upper}}"
        CACHE
        FILEPATH
        "When not empty, overrides where to find CMake cmsis-stm32 index for ${target}"
    )

    if(CMSIS_STM32_INDEX_${target_upper})
        include(CMSIS_STM32_INDEX_${target_upper})
    else()
        if(target_arg_VERSION STREQUAL "LATEST")
            set(index_url https://github.com/rafaelmartins/cmsis-stm32/releases/latest/download/index.cmake)
        else()
            set(index_url https://github.com/rafaelmartins/cmsis-stm32/releases/download/${target_arg_VERSION}/index.cmake)
        endif()
        set(index_file "${CMAKE_CURRENT_BINARY_DIR}/cmsis-stm32-index-${target}/index.cmake")
        if(EXISTS "${index_file}")
            block()
                include("${index_file}")
                if(NOT ${target_arg_VERSION} STREQUAL ${STM32_CMSIS_VERSION})
                    file(REMOVE "${index_file}")
                endif()
            endblock()
        endif()
        if(NOT EXISTS "${index_file}")
            file(DOWNLOAD "${index_url}" "${index_file}" STATUS index_status)
            list(GET index_status 0 index_status_code)
            if(NOT index_status_code EQUAL 0)
                file(REMOVE "${index_file}")
                if(index_status_code EQUAL 22)
                    message(FATAL_ERROR "Invalid cmsis-stm32 VERSION: ${target_arg_VERSION}")
                else()
                    list(GET index_status 1 index_status_msg)
                    message(FATAL_ERROR "Failed to fetch cmsis-stm32 index: ${index_status_msg}")
                endif()
            endif()
        endif()
        include("${index_file}")
    endif()

    string(TOLOWER "${target_arg_DEVICE}" mcu_lower)

    foreach(family ${STM32_CMSIS_FAMILIES})
        string(LENGTH "${family}" family_len)
        string(SUBSTRING "${mcu_lower}" 0 ${family_len} mcu_prefix)
        string(TOLOWER "${mcu_prefix}" mcu_prefix)
        if(mcu_prefix STREQUAL family)
            set(mcu_family "${family}")
            break()
        endif()
    endforeach()
    if(NOT mcu_family)
        message(FATAL_ERROR "Unsupported STM32 family: ${target_arg_DEVICE}")
    endif()

    FetchContent_Declare(cmsis-${mcu_family}-${target}
        URL https://github.com/rafaelmartins/cmsis-stm32/releases/download/${STM32_CMSIS_VERSION}/${STM32_CMSIS_DIST_${mcu_family}}.tar.xz
        URL_HASH MD5=${STM32_CMSIS_DIST_MD5_${mcu_family}}
        DOWNLOAD_EXTRACT_TIMESTAMP ON
    )
    FetchContent_MakeAvailable(cmsis-${mcu_family}-${target})

    block()
        set(cmsis_stm32_library_target_name cmsis-${target})
        include("${cmsis-${mcu_family}-${target}_SOURCE_DIR}/cmake/${mcu_lower}.cmake")
    endblock()

    target_link_libraries(${target} PRIVATE
        cmsis-${target}
    )

    target_link_options(${target} PRIVATE
        "-T${target_arg_LINKER_SCRIPT}"
    )

    if(target_arg_INSTALL)
        install(TARGETS ${target})
    endif()

    if(generate_map)
        target_link_options(${target} PRIVATE
            "-Wl,-Map,$<TARGET_FILE:${target}>.map"
        )
        set_property(TARGET ${target}
            APPEND
            PROPERTY ADDITIONAL_CLEAN_FILES "$<TARGET_FILE:${target}>.map"
        )
        if(target_arg_INSTALL)
            install(FILES
                "$<TARGET_FILE:${target}>.map"
                TYPE BIN
            )
        endif()
    endif()

    if(generate_bin)
        add_custom_command(
            OUTPUT ${target}.bin
            COMMAND
                "${CMAKE_OBJCOPY}"
                    -O binary
                    "$<TARGET_FILE:${target}>"
                    "${target}.bin"
            DEPENDS "$<TARGET_FILE:${target}>"
        )

        add_custom_target(${target}-bin
            ALL
            DEPENDS ${target}.bin
        )

        if(target_arg_INSTALL)
            install(PROGRAMS
                "${CMAKE_CURRENT_BINARY_DIR}/${target}.bin"
                TYPE BIN
            )
        endif()
    endif()

    if(generate_ihex)
        add_custom_command(
            OUTPUT ${target}.hex
            COMMAND
                "${CMAKE_OBJCOPY}"
                    -O ihex "$<TARGET_FILE:${target}>"
                    "${target}.hex"
            DEPENDS "$<TARGET_FILE:${target}>"
        )

        add_custom_target(${target}-ihex
            ALL
            DEPENDS ${target}.hex
        )

        if(target_arg_INSTALL)
            install(FILES
                "${CMAKE_CURRENT_BINARY_DIR}/${target}.hex"
                TYPE BIN
            )
        endif()
    endif()

    if(generate_s19 OR generate_dfu)
        add_custom_command(
            OUTPUT ${target}.s19
            COMMAND
                "${CMAKE_OBJCOPY}"
                    -O srec "$<TARGET_FILE:${target}>"
                    "${target}.s19"
            DEPENDS "$<TARGET_FILE:${target}>"
        )

        add_custom_target(${target}-s19
            ALL
            DEPENDS ${target}.s19
        )

        if(generate_s19 AND target_arg_INSTALL)
            install(PROGRAMS
                "${CMAKE_CURRENT_BINARY_DIR}/${target}.s19"
                TYPE BIN
            )
        endif()
    endif()

    if(generate_dfu)
        find_program(DFUSE_PACK
            NAMES dfuse-pack.py dfuse-pack
            REQUIRED
        )

        add_custom_command(
            OUTPUT ${target}.dfu
            COMMAND
                "${DFUSE_PACK}"
                    -s "${target}.s19"
                    "${target}.dfu"
            DEPENDS ${target}.s19
        )

        add_custom_target(${target}-dfu
            ALL
            DEPENDS ${target}.dfu
        )

        if(target_arg_INSTALL)
            install(FILES
                "${CMAKE_CURRENT_BINARY_DIR}/${target}.dfu"
                TYPE BIN
            )
        endif()
    endif()

    if(target_arg_SHOW_SIZE)
        find_program(ARM_SIZE "${CMAKE_SYSTEM_PROCESSOR}-size" REQUIRED)

        add_custom_command(
            TARGET ${target}
            POST_BUILD
            COMMAND
                "${ARM_SIZE}"
                    --format=berkeley
                    "$<TARGET_FILE:${target}>"
        )
    endif()

    if(target_arg_STLINK)
        find_program(ST_FLASH st-flash)
        if(NOT ST_FLASH)
            message(STATUS "st-flash not installed, ignoring.")
        else()
            if(DEFINED STLINK_RESET)
                set(STLINK_RESET "${STLINK_RESET}" CACHE BOOL "stlink tools reset")
            else()
                set(STLINK_RESET ON CACHE BOOL "stlink tools reset")
            endif()
            if(STLINK_RESET)
                set(STLINK_RESET_ARG "--reset")
            endif()

            set(STLINK_CONNECT_UNDER_RESET "${STLINK_CONNECT_UNDER_RESET}" CACHE BOOL "stlink tools connect under reset")
            if(STLINK_CONNECT_UNDER_RESET)
                set(STLINK_CONNECT_UNDER_RESET_ARG "--connect-under-reset")
            endif()

            set(STLINK_HOTPLUG "${STLINK_HOTPLUG}" CACHE BOOL "stlink tools hot plug")
            if(STLINK_HOTPLUG)
                set(STLINK_HOTPLUG_ARG "--hot-plug")
            endif()

            set(STLINK_FREQ "${STLINK_FREQ}" CACHE STRING "stlink tools frequency in khz")
            if(NOT STLINK_FREQ STREQUAL "")
                set(STLINK_FREQ_ARG "--freq=${STLINK_FREQ}")
            endif()

            set(STLINK_SERIAL "${STLINK_SERIAL}" CACHE STRING "stlink tools serial number (from st-info --serial)")
            if(NOT STLINK_SERIAL STREQUAL "")
                set(STLINK_SERIAL_ARG "--serial=${STLINK_SERIAL}")
            endif()

            if(NOT TARGET stlink-erase)
                add_custom_target(stlink-erase
                    "${ST_FLASH}"
                        ${STLINK_CONNECT_UNDER_RESET_ARG}
                        ${STLINK_HOTPLUG_ARG}
                        ${STLINK_FREQ_ARG}
                        ${STLINK_SERIAL_ARG}
                        erase
                    USES_TERMINAL
                )

                add_custom_target(stlink-reset
                    "${ST_FLASH}"
                        ${STLINK_FREQ_ARG}
                        ${STLINK_SERIAL_ARG}
                        reset
                    USES_TERMINAL
                )
            endif()

            add_custom_target(${target}-stlink-write
                "${ST_FLASH}"
                    ${STLINK_RESET_ARG}
                    ${STLINK_CONNECT_UNDER_RESET_ARG}
                    ${STLINK_HOTPLUG_ARG}
                    ${STLINK_FREQ_ARG}
                    ${STLINK_SERIAL_ARG}
                    --format ihex
                    write "${target}.hex"
                DEPENDS ${target}.hex
                USES_TERMINAL
            )
        endif()
    endif()
endfunction()
