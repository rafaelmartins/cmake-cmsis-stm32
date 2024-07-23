# SPDX-FileCopyrightText: 2023-2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.17)

project(example C ASM)

add_executable(example-f042
    main-f042.c
)

target_compile_options(example-f042 PRIVATE
    -Wall
    -Wextra
    -Werror
)

set_property(TARGET example-f042
    PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE
)

cmsis_stm32_target(example-f042
    DEVICE STM32F042x6
    VERSION 20240709193138
    LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F042K6Tx_FLASH.ld
    ADDITIONAL_OUTPUTS BIN MAP IHEX DFU S19
    SHOW_SIZE ON
    STLINK ON
    INSTALL ON
)

add_executable(example-g431
    main-g431.c
)

target_compile_definitions(example-g431 PRIVATE
    USE_HSI=1
)

target_compile_options(example-g431 PRIVATE
    -Wall
    -Wextra
    -Werror
)

set_property(TARGET example-g431
    PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE
)

cmsis_stm32_target(example-g431
    DEVICE STM32G431xx
    VERSION 20240709193138
    LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32G431KBTx_FLASH.ld
    ADDITIONAL_OUTPUTS BIN MAP IHEX DFU S19
    SHOW_SIZE ON
    STLINK ON
    INSTALL ON
)
