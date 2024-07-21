# ultra96v2-platform
Scripts to build a basic hardware platform for the [ultra96v2](https://www.avnet.com/wps/portal/us/products/new-product-introductions/npi/aes-ultra96-v2/) 
Zynq UltraScale+ MPSoC development board.

Includes:
- Dockerfile to build development container containing Xilinx toolchain (Vivado, Vitis) 
  and open source development tools (GCC, Verilator, Verible)
- Devcontainer and vscode configuration for IDE-like features (Intellisense, goto definition, etc.)
- Dockerfile to generate a bootable ubuntu-based image for the ultra96v2 development board
- TCL scripts to generate a bitstream using Vivado non-project flow

## Using this platform as a submodule

Add a makefile in the root of your project directory with the following lines:

```
export PFM_DIR := ultra96v2-platform

BD_SRC := vivado/bd.tcl

include $(PFM_DIR)/Makefile
```
Here `PFM_DIR` is the relative path to the ultra96v2-platform repo submodule.
Different default components from the platform makefile can be overridden.
In this example, a custom vivado block design is specified.

## Building development container

1. Download the Xilinx Unified Installer, Single File Download version (tar archive).
   Despite the large file size this has proved to be faster and more robust than using the
   self-extracting installer in a docker build.
1. Copy the installer archive to the `docker` folder
1. Run `make docker-image` to build the development container, which installs the Xilinx toolchain.
   This takes a long time.
1. If necessary to save disk space, remove the installer from the `static` folder

## Building, Booting ubuntu image

1. Run `make` to build the bootable image and default bitstream.
1. Run `make sd SD_DEV=<sd device name>` to partition and copy the files to the specified device. For example, `sda` for `/dev/sda`
1. Boot the image on the development board. Ensure that the boot DIP switches are in the SD card position.

## Updating xilinx tool versions

1. Update `XIL_VERSION`, `XIL_INSTALLER` and `XIL_INSTALLER_MD5` in the `Makefile`
1. Update branch/tag of submodules to new release
1. Re-build docker image with `make docker-image`
1. Update block design IP versions with `make edit-bd`, if necessary
1. Update u-boot config: copy `submodules/u-boot/configs/xilinx_zynqmp_virt_defconfig` to `bsp/ultra96v2_uboot_defconfig`, updating as necessary
1. Update linux config: copy `submodules/linux/arch/arm64/configs/xilinx_zynqmp_defconfig` to `bsp/ultra96v2_linux_defconfig`, updating as necessary
