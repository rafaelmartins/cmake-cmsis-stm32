---
menu: Main
---
A CMake module for STM32 bare-metal firmware projects. It handles CMSIS integration, cross-compilation toolchain setup, and firmware output generation through a single function call.

## What it does

Including `cmake-cmsis-stm32` via `FetchContent` and calling `cmsis_stm32_target()` on your executable target is all it takes. The module downloads the correct CMSIS device headers and startup code from [cmsis-stm32](@@/p/cmsis-stm32/) releases, sets the appropriate CPU and FPU compiler flags for your device, links the startup and system initialization code, and applies your linker script -- no manual setup required. A default ARM GCC toolchain (`arm-none-eabi`) file is provided if none is specified.

## Key highlights

- **Single-function API** -- one call to `cmsis_stm32_target()` configures everything for a given target
- **Automatic CMSIS integration** -- device headers and startup code are resolved and downloaded per device identifier
- **Multiple output formats** -- generate `BIN`, `IHEX`, `S19`, `DFU`, and `MAP` files alongside the ELF
- **ST-Link support** -- creates per-target build targets for programming and erasing via `st-flash`
- **Default toolchain** -- ships a `gcc-arm-none-eabi` toolchain file, used automatically when no custom toolchain is set
- **Size reporting and install support** -- optional post-build size output and `CPack`-compatible install targets

## Usage

The `FetchContent` block must appear **before** the `project()` call, as it sets the cross-compilation toolchain:

```cmake
cmake_minimum_required(VERSION 3.25)

include(FetchContent)
FetchContent_Declare(cmake_cmsis_stm32
    GIT_REPOSITORY https://github.com/rafaelmartins/cmake-cmsis-stm32.git
    GIT_TAG main
)
FetchContent_MakeAvailable(cmake_cmsis_stm32)

project(my-firmware C ASM)

add_executable(my-firmware main.c)

cmsis_stm32_target(my-firmware
    DEVICE STM32F042x6
    VERSION LATEST
    LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F042K6Tx_FLASH.ld
    ADDITIONAL_OUTPUTS BIN IHEX MAP
    SHOW_SIZE ON
    STLINK ON
)
```

See the [firmware development guide](80_firmware-development.md) for a complete walkthrough of all parameters and usage patterns.

## Requirements

- CMake 3.25 or later
- [ARM GNU Toolchain (`arm-none-eabi`)](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- Project must enable `C` and `ASM` languages

## Links

- [Firmware development guide](80_firmware-development.md)
- [cmsis-stm32 project page](@@/p/cmsis-stm32/)
- [GitHub repository](https://github.com/rafaelmartins/cmake-cmsis-stm32/)
