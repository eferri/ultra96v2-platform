# ultra96v2-platform
Scripts to build a basic hardware platform for the [ultra96v2](https://www.avnet.com/wps/portal/us/products/new-product-introductions/npi/aes-ultra96-v2/) 
Zynq UltraScale+ MPSoC development board.

Includes:
- Dockerfile to build development container containing Xilinx toolchain (Vivado, Vitis, Petalinux) 
  and open source development tools (Verilator, Verible)
- Devcontainer and vscode configuration for IDE-like features (Intellisense, goto definition, etc.)
- Minimal petalinux project to generate a bootable image for ultra96v2 development board
- TCL scripts to generate a bitstream using Vivado non-project flow
- Boilerplate simulation code for the Vivado simulator (xsim)

## Building development container

1. Download the Xilinx Unified Installer, Single File Download version (tar archive). 
   Despite the large file size this has proved to be faster and more robust than using the 
   self-extracting installer in a docker build.
1. Copy the installer archive to the `static` folder
1. Run `make docker-image` to build the development container, which installs the Xilinx toolchain. 
   This may take longer than 1 hour.
1. If necessary to save disk space, remove the installer from the `static` folder

## Opening vscode in development container

1. From the command palette (`ctrl + shift + P`) run `Dev Containers: Rebuild and Reopen in Container`

## Building, Booting petalinux image

1. Run `make petalinux-build && make petalinux-package`. 
   This will build the XSA file as well as the linux kernel and root filesystem. 
   Note that the XSA file generated is a fixed platform for software only.
1. From the `petalinux/images` directory, flash the `petalinux-sdimage.wic` file onto an SD card using a tool such as `dd`.
1. Boot the image on the development board. Ensure that the boot DIP switches are in the SD card position.

## Build bitstream

1. Run `make bit` to build a boilerplate bitstream. 
   This can be loaded via JTAG or with the `fpga-manager` utility on the device
