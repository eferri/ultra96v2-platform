#!/bin/bash
set -eu

rm -rf /app/build-sw/machine
mkdir /app/build-sw/machine

qemu-system-microblazeel \
    -M microblaze-fdt \
    -serial mon:stdio \
    -serial null \
    -display none \
    -kernel /xilinx/Vitis/2023.1/data/emulation/dtbs/zynqmp/pmu_rom_qemu_sha3.elf \
    -device loader,file=/app/build-sw/zynqmp_pmufw.elf \
    -hw-dtb /app/build-sw/qemu_pmu.dtb \
    -machine-path /app/build-sw/machine \
    -device loader,addr=0xfd1a0074,data=0x1011003,data-len=4 \
    -device loader,addr=0xfd1a007C,data=0x1010f03,data-len=4 \
    &

# qemu-system-aarch64 
#    -M arm-generic-fdt
#    -serial mon:stdio
#    -serial /dev/null
#    -display none
#    -device loader,file=xilinx-zcu102-2023.1/pre-built/linux/images/bl31.elf,cpu-num=0
#    -device loader,file=xilinx-zcu102-2023.1/pre-built/linux/images/system.dtb,addr=0x00100000,force-raw=on
#    -device loader,file=xilinx-zcu102-2023.1/pre-built/linux/images/u-boot.elf
#    -gdb tcp::9000
#    -net nic
#    -net nic
#    -net nic
#    -net nic,netdev=eth0
#    -netdev user,id=eth0,tftp=/tftpboot
#    -hw-dtb xilinx-zcu102-2023.1/pre-built/linux/images/zynqmp-qemu-multiarch-arm.dtb
#    -machine-path /tmp/tmp.IvztcLUUKB
#    -global xlnx,zynqmp-boot.cpu-num=0
#    -global xlnx,zynqmp-boot.use-pmufw=true
#    -m 4G

qemu-system-aarch64 \
    -M arm-generic-fdt \
    -serial null \
    -serial mon:stdio \
    -nographic \
    -m 4G \
    -gdb tcp::9000 \
    -net nic \
    -net nic \
    -net nic \
    -net nic,netdev=eth0 \
    -netdev user,id=eth0 \
    -machine-path /app/build-sw/machine \
    -hw-dtb /app/build-sw/qemu_system.dtb \
    -drive if=sd,index=1,file=/app/build-sw/qemu.img,format=raw \
    -device loader,file=/app/build-sw/bl31.elf,cpu-num=0 \
	-device loader,file=/app/build-sw/u-boot.elf \
	-device loader,file=/app/build-sw/image.ub,addr=0x10000000,force-raw=on \
    -device loader,file=/app/build-sw/qemu_boot.scr,addr=0x20000000,force-raw=on \
    -global xlnx,zynqmp-boot.cpu-num=0 \
    -global xlnx,zynqmp-boot.use-pmufw=true
