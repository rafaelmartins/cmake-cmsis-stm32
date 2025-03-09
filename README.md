# cmake-cmsis-stm32

CMake module containing CMSIS headers for STMicroelectronics Series of ARM Cortex-M microcontrollers.

## How to use

Edit your main `CMakeLists.txt` file and add the following snippet **before** the `project()` call:

```cmake
include(FetchContent)

FetchContent_Declare(cmake_cmsis_stm32
    GIT_REPOSITORY https://github.com/rafaelmartins/cmake-cmsis-stm32.git
)
FetchContent_MakeAvailable(cmake_cmsis_stm32)
```

Consider adding a `GIT_TAG` parameter to `FetchContent_Declare()` to pin your project to a specific commit in this repository.

Assuming that there's a `main` target defined in your `CMakeLists.txt` file, add the following snipped to create the `cmsis-stm32`-specific targets:

```cmake
cmsis_stm32_target(main
    DEVICE STM32F042x6
    VERSION 20240709193138
    LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F042KxTx_FLASH.ld
    ADDITIONAL_OUTPUTS BIN MAP IHEX DFU
    SHOW_SIZE ON
    STLINK ON
    INSTALL ON
)
```

The `DEVICE` parameter should contain the device definition for the microcontroller being used, as expected by the device's headers.

The `VERSION` parameter should point to a [`cmsis-stm32` release](https://github.com/rafaelmartins/cmsis-stm32/releases).

The `LINKER_SCRIPT` must exist is not handled automatically by this project; it must be provided by the user. As we use the default startup scripts from `ST`, it is recommended to use linker scripts created by `STM32CubeMX` because they define the variables expected by the startup scripts.

The `ADDITIONAL_OUTPUTS` parameters contain a space-separated list of formats to be generated, other than a `ELF` binary.

The `SHOW_SIZE` parameter enables showing the size of the binary after building them.

The `STLINK` parameter creates targets to allow interacting with the microcontroller using [`stlink`](https://github.com/stlink-org/stlink).

The `INSTALL` parameter adds the generated files to `install` target. This is useful when generating distribution tarballs using `CPack`.

## License
This code is released under a [BSD 3-Clause License](LICENSE).
