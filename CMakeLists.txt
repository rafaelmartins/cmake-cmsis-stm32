# SPDX-FileCopyrightText: 2023-2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.25)

include(${CMAKE_CURRENT_LIST_DIR}/cmake/cmsis-stm32.cmake)

project(cmake-cmsis-stm32)

if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory(example)
endif()
