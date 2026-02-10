# Firmware Development

This guide covers firmware development with cmake-cmsis-stm32 -- from project setup to flashing your device.


## Integrating cmake-cmsis-stm32

Add the module to your project via CMake's `FetchContent`. The `FetchContent_Declare` and `FetchContent_MakeAvailable` calls **must appear before** `project()` because the module sets the default toolchain file when no toolchain is specified.

```cmake
cmake_minimum_required(VERSION 3.25)

include(FetchContent)
FetchContent_Declare(cmake_cmsis_stm32
    GIT_REPOSITORY https://github.com/rafaelmartins/cmake-cmsis-stm32.git
    GIT_TAG main
)
FetchContent_MakeAvailable(cmake_cmsis_stm32)

project(my-firmware C ASM)
```

Pin to a specific commit by replacing `main` with a commit SHA in the `GIT_TAG` parameter. This prevents unexpected changes from breaking your build.

The module checks `CMAKE_TOOLCHAIN_FILE` and the `CMAKE_TOOLCHAIN_FILE` environment variable. If neither is set, the bundled toolchain file is used automatically.


## Defining a Firmware Target

Create an executable target with `add_executable`, then configure it with `cmsis_stm32_target()`:

```cmake
add_executable(firmware
    main.c
)

cmsis_stm32_target(firmware
    DEVICE STM32F042x6
    VERSION LATEST
    LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F042K6Tx_FLASH.ld
)
```

`cmsis_stm32_target()` must be called after `add_executable`. The function links CMSIS startup code and headers to your target, applies the linker script, and configures CPU-specific compiler flags.


### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `DEVICE` | Device identifier recognized by ST CMSIS headers |
| `VERSION` | cmsis-stm32 release tag or `LATEST` |
| `LINKER_SCRIPT` | Path to a linker script compatible with ST CMSIS startup code |


## Selecting a Device

The `DEVICE` parameter must match identifiers used by ST's CMSIS device headers. These follow the pattern `STM32<family><variant>` -- for example, `STM32F042x6`, `STM32G431xx`, or `STM32L476xx`.

Consult the [cmsis-stm32 project page](@@/p/cmsis-stm32/) for the list of supported device families and their identifiers.

The device identifier determines:

- The startup assembly file
- The system initialization code
- CPU-specific compiler and linker flags (`-mcpu`, `-mthumb`)
- Preprocessor definitions (e.g., `STM32F042x6=1`, `STM32F0xx=1`)


## Specifying a cmsis-stm32 Version

The `VERSION` parameter accepts either `LATEST` or a specific release tag.

```cmake
# Always fetch the most recent release
cmsis_stm32_target(firmware
    ...
    VERSION LATEST
)

# Pin to a specific release
cmsis_stm32_target(firmware
    ...
    VERSION <release-tag>
)
```

Find available release tags on the [cmsis-stm32 releases page](https://github.com/rafaelmartins/cmsis-stm32/releases).

When using `LATEST`, the module downloads the index file from the latest release. For a specific version, the URL includes the tag directly. The downloaded index is cached in your build directory. If you change `VERSION`, the cached index is automatically invalidated and re-downloaded.


## Linker Scripts

cmake-cmsis-stm32 does **not** provide linker scripts. You must supply one via the `LINKER_SCRIPT` parameter.

The linker script must be compatible with ST's CMSIS startup code. It should define:

- Memory regions (`FLASH`, `RAM`) with correct origins and lengths
- The `_estack` symbol pointing to the end of RAM
- Standard sections expected by the startup code (`.isr_vector`, `.data`, `.bss`)

The easiest way to obtain a valid linker script is to generate one with STM32CubeMX for your specific device. The startup code in cmsis-stm32 originates from ST's CMSIS Device packages, so CubeMX-generated linker scripts are directly compatible.


## Output Formats

By default, `cmsis_stm32_target()` produces only an ELF binary. Use `ADDITIONAL_OUTPUTS` to generate other formats:

```cmake
cmsis_stm32_target(firmware
    ...
    ADDITIONAL_OUTPUTS BIN IHEX S19 DFU MAP
)
```

| Format | Description | Output File |
|--------|-------------|-------------|
| `BIN` | Raw binary | `<target>.bin` |
| `IHEX` | Intel HEX | `<target>.hex` |
| `S19` | Motorola S-record | `<target>.s19` |
| `DFU` | DfuSe format for USB DFU | `<target>.dfu` |
| `MAP` | Linker map file | `<target>.elf.map` |

Each format creates a corresponding CMake target (`<target>-bin`, `<target>-ihex`, etc.) that builds by default.


### DFU Generation

DFU output requires `dfuse-pack.py` from [dfu-util](https://dfu-util.sourceforge.net/). The module searches for `dfuse-pack.py` or `dfuse-pack` in your `PATH`. If not found, it downloads the script automatically -- this requires Python 3.

DFU generation internally depends on S19, so requesting `DFU` also generates the S-record file.


## Binary Size Reporting

Enable `SHOW_SIZE` to display firmware size after each build:

```cmake
cmsis_stm32_target(firmware
    ...
    SHOW_SIZE ON
)
```

This runs `arm-none-eabi-size --format=berkeley` on the ELF file as a post-build step, showing text, data, and bss segment sizes.


## Programming with ST-Link

Enable `STLINK` to generate programming targets:

```cmake
cmsis_stm32_target(firmware
    ...
    STLINK ON
)
```

This creates three targets when `st-flash` is available in your `PATH`:

| Target | Command |
|--------|---------|
| `<target>-stlink-write` | Writes the HEX file to flash |
| `stlink-erase` | Erases flash memory |
| `stlink-reset` | Resets the device |

`stlink-erase` and `stlink-reset` are shared across all targets in the project and created only once.

Enabling `STLINK` automatically generates Intel HEX output regardless of `ADDITIONAL_OUTPUTS`.


### ST-Link Configuration

Per-target cache variables control `st-flash` behavior. Set these via `-D` on the CMake command line or in `ccmake`/`cmake-gui`. The variable names use the CMake target name as a prefix.

| Variable | Type | Default | st-flash Flag |
|----------|------|---------|---------------|
| `<target>_STLINK_RESET` | `BOOL` | `ON` | `--reset` |
| `<target>_STLINK_CONNECT_UNDER_RESET` | `BOOL` | `OFF` | `--connect-under-reset` |
| `<target>_STLINK_HOTPLUG` | `BOOL` | `OFF` | `--hot-plug` |
| `<target>_STLINK_FREQ` | `STRING` | (empty) | `--freq=<value>` |
| `<target>_STLINK_SERIAL` | `STRING` | (empty) | `--serial=<value>` |

For `<target>_STLINK_SERIAL`, obtain the serial number with `st-info --serial`.

Example:

```bash
cmake -B build -Dfirmware_STLINK_CONNECT_UNDER_RESET=ON
cmake --build build --target firmware-stlink-write
```


## Installation and Packaging

Enable `INSTALL` to include firmware outputs in CMake's install targets:

```cmake
cmsis_stm32_target(firmware
    ...
    INSTALL ON
)
```

This adds the ELF binary and any additional outputs to the install target. Combined with CPack, this allows generating distribution archives:

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
cmake --install build
cpack --config build/CPackConfig.cmake
```


## Toolchain Configuration

When no toolchain file is specified, the module uses its bundled toolchain for the ARM GNU Toolchain (`arm-none-eabi-gcc`).


### Default Configuration

The bundled toolchain sets:

| Setting | Value |
|---------|-------|
| `CMAKE_SYSTEM_NAME` | `Generic-ELF` |
| `CMAKE_SYSTEM_PROCESSOR` | `arm-none-eabi` |
| C/ASM Compiler | `arm-none-eabi-gcc` |
| C++ Compiler | `arm-none-eabi-g++` |
| Compiler Flags | `-ggdb3 -fdata-sections -ffunction-sections` |

Debug symbols (`-ggdb3`) are always included because they remain in the ELF file and are stripped when generating binary outputs. The `-fdata-sections` and `-ffunction-sections` flags enable dead code elimination (see [Build Optimization](#build-optimization)).

Cross-compilation isolation is configured to search for libraries and headers only in the toolchain's sysroot, not the host system.


### Using a Custom Toolchain

To use a different toolchain, set `CMAKE_TOOLCHAIN_FILE` before the `FetchContent` block or via the environment:

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake
```

```bash
CMAKE_TOOLCHAIN_FILE=/path/to/toolchain.cmake cmake -B build
```

The module only sets the toolchain if neither `CMAKE_TOOLCHAIN_FILE` nor the `CMAKE_TOOLCHAIN_FILE` environment variable is defined.


## Using a Custom CMSIS Index

For offline builds or custom CMSIS packages, override the index location with the `CMSIS_STM32_INDEX_<TARGET>` cache variable. The target name is converted to uppercase.

```bash
cmake -B build -DCMSIS_STM32_INDEX_FIRMWARE=/path/to/index.cmake
```

The custom index file must define the same variables as the official index:

- `STM32_CMSIS_VERSION` -- release identifier
- `STM32_CMSIS_FAMILIES` -- list of supported family prefixes
- `STM32_CMSIS_DIST_<family>` -- archive name for each family
- `STM32_CMSIS_DIST_MD5_<family>` -- MD5 hash for verification

This is useful for air-gapped environments or when testing unreleased CMSIS packages.


## Build Optimization

For minimal firmware binaries, enable Link-Time Optimization (LTO):

```cmake
add_executable(firmware
    main.c
)

set_property(TARGET firmware
    PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE
)

cmsis_stm32_target(firmware
    ...
)
```

LTO allows the compiler to optimize across translation units, eliminating unused functions and inlining across file boundaries.

The bundled toolchain's `-ffunction-sections` and `-fdata-sections` flags place each function and data object in its own section. The CMSIS library applies `-Wl,--gc-sections` during linking, which discards unreferenced sections. Together with LTO, this produces significantly smaller binaries.


## Building

Configure and build with standard CMake commands:

```bash
cmake -B build
cmake --build build
```

For programming via ST-Link:

```bash
cmake --build build --target firmware-stlink-write
```

For flash operations:

```bash
cmake --build build --target stlink-erase
cmake --build build --target stlink-reset
```
