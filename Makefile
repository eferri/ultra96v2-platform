PART ?= xczu3eg-sbva484-1-e

#
# inputs
#

UID ?= 1000
GID ?= 1000
KVM_GID ?= 109

XIL_VERSION := 2023.1
XIL_INSTALLER := Xilinx_Unified_$(XIL_VERSION)_0507_1903
XIL_INSTALLER_TAR := $(XIL_INSTALLER).tar.gz
XIL_INSTALLER_MD5 := f2011ceba52b109e3551c1d3189a8c9c

RTL_SRCS ?= \
	rtl/top.sv \
	rtl/flash.sv

SYNTH_SRCS ?= $(RTL_SRCS)

SIM_SRCS ?=

ALL_SRCS := $(RTL_SRCS) $(SIM_SRCS)

#
# outputs
#

# bsp
DTS := build-sw/system.dts
DTB := build-sw/system.dtb

ATF := build-sw/bl31.elf
PMUFW := build-sw/zynqmp_pmufw.bin

BOOT_BIN := build-sw/BOOT.bin
FSBL := build-sw/zynqmp_fsbl.elf
U_BOOT := build-sw/u-boot.elf
LINUX := build-sw/Image
FIT := build-sw/image.ub

ROOTFS := build-sw/rootfs.tar.gz

# fpga
BIT := build-hw/system.bit
IMPL := build-hw/impl.dcp
SYNTH := build-hw/synth.dcp
XSA := build-hw/zynqmp.xsa
BD := build-hw/bd/zynqmp/zynqmp.bd


.PHONY: all
all: $(BOOT_BIN) $(FIT) $(ROOTFS)

#
# docker
#

# Run command in bash shell with xilinx tools sourced
DOCKER_RUN := docker compose run --rm xil
XIL_BASH := $(DOCKER_RUN) bash -ic

.PHONY: shell
shell:
	docker compose run --rm xil bash -i

.PHONY: root-shell
root-shell:
	docker compose run --user root --rm xil bash -i

.PHONY: docker
docker-image: $(XILINX_TOKEN)
	docker compose up -d server \
	&& docker compose build xil --progress=plain \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg KVM_GID=$(KVM_GID) \
		--build-arg XIL_VERSION=$(XIL_VERSION) \
		--build-arg XIL_INSTALLER=$(XIL_INSTALLER) \
		--build-arg XIL_INSTALLER_TAR=$(XIL_INSTALLER_TAR) \
		--build-arg XIL_INSTALLER_MD5=$(XIL_INSTALLER_MD5) \
	&& docker compose down

#
# Generate filelist for verible tools
#

SINGLE_LINE_SRCS := $(patsubst %,%,$(ALL_SRCS))

SRC_HASH = SRCS_$(shell echo '$($(1))' | md5sum | awk '{print $$1}')

verible.filelist: build-sw/$(call SRC_HASH,SINGLE_LINE_SRCS)
	rm -f $@
	echo $(SINGLE_LINE_SRCS) | sed 's/ /\n/g' > $@

build-sw/$(call SRC_HASH,SINGLE_LINE_SRCS): | build-sw
	rm -rf build-sw/SRCS*
	touch $@

#
# vivado
#

VIVADO_ARGS := -nojournal -nolog

.PHONY: impl bit
impl bit $(IMPL) $(BIT): $(SYNTH) vivado/bitstream.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/bitstream.tcl'

.PHONY: synth
synth $(SYNTH): vivado/synth.tcl $(BD) vivado/constraints.xdc $(SYNTH_SRCS) | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/synth.tcl -tclargs $(PART) $(SYNTH_SRCS)'

.PHONY: bd xsa
bd xsa $(BD) $(XSA): vivado/write_bd.tcl vivado/bd.tcl vivado/zynqmp_preset.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/write_bd.tcl -tclargs $(PART)'

# Interactive commands
.PHONY: vivado-shell
vivado-shell:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl'

.PHONY: vivado-gui
vivado-gui:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS)'

.PHONY: edit-bd
edit-bd: | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl -source vivado/edit_bd.tcl -tclargs $(PART)'


#
# platform software
#

DTS_SRCS := \
	device-tree/system-top.dts \
	device-tree/system-bsp.dtsi \
	device-tree/pcw.dtsi \
	device-tree/zynqmp-clk-ccf.dtsi \
	device-tree/zynqmp.dtsi

# Generate dts and pm_cfg_obj from xsct

.PHONY: dts-gen
dts-gen: $(XSA) scripts/dts.tcl
	$(XIL_BASH) 'xsct scripts/dts.tcl'

.PHONY: dtb
dtb $(DTB) $(DTS): $(DTS_SRCS) | build-sw
	$(XIL_BASH) 'gcc -I device-tree -I submodules/linux -E -nostdinc -undef \
					 -D__DTS__ -x assembler-with-cpp -o $(DTS) device-tree/system-top.dts \
	&& dtc -I dts -O dtb -o $(DTB) $(DTS) \
	&& make -C ./submodules/qemu-devicetrees \
	&& cp ./submodules/qemu-devicetrees/LATEST/MULTI_ARCH/board-zynqmp-zcu102.dtb ./build-sw/qemu_system.dtb \
	&& cp ./submodules/qemu-devicetrees/LATEST/MULTI_ARCH/zynqmp-pmu.dtb ./build-sw/qemu_pmu.dtb'

.PHONY: pmufw
pmufw $(PMUFW): | build-sw
	$(XIL_BASH) 'sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" ./submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/misc/xparameters.h \
	&& $(MAKE) CFLAGS="-Os -flto -ffat-lto-objects -DULTRA96_VERSION=2 -DENABLE_MOD_ULTRA96 -DENABLE_SCHEDULER" \
		-C submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src \
	&& mb-objcopy -O binary submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf $(PMUFW) \
	&& cp submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf build-sw/zynqmp_pmufw.elf'

.PHONY: atf
atf $(ATF): | build-sw
	$(XIL_BASH) '$(MAKE) -j$$(nproc) CROSS_COMPILE=aarch64-none-elf- PLAT=zynqmp ZYNQMP_CONSOLE=cadence1 RESET_TO_BL31=1 all \
		-C submodules/arm-trusted-firmware \
	&& cp submodules/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf $(ATF)'

.PHONY: fsbl
fsbl $(FSBL): $(XSA) | build-sw
	$(XIL_BASH) 'xsct ./scripts/fsbl.tcl \
	&& sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" ./build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/include/xparameters.h \
	&& $(MAKE) -C ./build-sw/fsbl \
	&& cp build-sw/fsbl/executable.elf $(FSBL) \
	&& cp build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/libsrc/xilpm_v5_0/src/pm_cfg_obj.c bsp/pm_cfg_obj.c'

.PHONY: u-boot
u-boot $(U_BOOT): $(DTS) bsp/ultra96v2_uboot_defconfig | build-sw
	$(XIL_BASH) 'mkdir -p submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
	&& cp $(DTS) submodules/u-boot/arch/arm/dts/ultra96v2.dts \
	&& cp bsp/ultra96v2_uboot_defconfig submodules/u-boot/configs/ultra96v2_defconfig \
	&& $(MAKE) -C submodules/u-boot ultra96v2_defconfig \
	&& CROSS_COMPILE=aarch64-linux-gnu- $(MAKE) -j$$(nproc) -C submodules/u-boot \
	&& cp submodules/u-boot/u-boot.elf $(U_BOOT)'

.PHONY: linux
linux $(LINUX): bsp/ultra96v2_linux_defconfig | build-sw
	$(XIL_BASH) 'cp bsp/ultra96v2_linux_defconfig submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& export CROSS_COMPILE=aarch64-linux-gnu- \
	&& $(MAKE) ARCH=arm64 -C submodules/linux ultra96v2_defconfig \
	&& $(MAKE) ARCH=arm64 -j$$(nproc) -C submodules/linux \
	&& cp submodules/linux/arch/arm64/boot/Image $(LINUX)'

.PHONY: bin
bin $(BOOT_BIN): $(DTB) $(FSBL) $(PMUFW) $(ATF) $(U_BOOT) | build-sw
	$(XIL_BASH) 'bootgen -arch zynqmp -image bsp/boot.bif -w -o $(BOOT_BIN)'

.PHONY: fit
fit $(FIT): $(LINUX) $(DTB) | build-sw
	$(XIL_BASH) 'mkimage -f ./bsp/image.its ./build-sw/image.ub $(FIT)'

.PHONY: rootfs
rootfs $(ROOTFS): | build-sw
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes \
	&& docker compose build rootfs \
	&& docker export "$$(docker create --platform linux/arm64/v8 rootfs:latest)" -o ./build-sw/docker_rootfs.tar \
	&& $(XIL_BASH) -c ' \
	rm -rf ./build-sw/machine ./build-sw/rootfs.tar.gz ./build-sw/qemu.img \
	&& qemu-img create -f raw ./build-sw/qemu.img 1G \
	&& guestfish -f ./scripts/guestfish_rootfs.sh \
	&& mkimage -A arm64 -C None -T script -d ./bsp/qemu_boot.script ./build-sw/qemu_boot.scr'


.PHONY: rootfs-shell
rootfs-shell:
	docker compose run --rm rootfs bash -i

.PHONY: qemu
qemu: $(U_BOOT) $(FIT) $(ROOTFS) $(ATF) $(PMUFW)
	$(XIL_BASH) './scripts/qemu.sh'

#
# target
#

.PHONY: hw-debug
hw-debug:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source scripts/debug.tcl'

.PHONY: boot
boot:
	$(XIL_BASH) 'xsdb -interactive scripts/boot.tcl'

# SD card files to install
INSTALL_FILES := \
	$(BOOT_BIN) \
	$(FIT) \
	bsp/extlinux

.PHONY: sd
sd: |
	./scripts/sd_utils.sh all $(INSTALL_FILES)

.PHONY: sd-mount
sd-mount: |
	./scripts/sd_utils.sh mount

.PHONY: sd-unmount
sd-unmount: |
	./scripts/sd_utils.sh unmount

.PHONY: sd-eject
sd-eject: |
	./scripts/sd_utils.sh eject

.PHONY: sd-partition
sd-partition: |
	./scripts/sd_utils.sh partition

#
# xinlinx installer
#

.PHONY: xilinx-extract
xilinx-extract docker/$(XIL_INSTALLER):
	md5sum docker/$(XIL_INSTALLER_TAR) | grep $(XIL_INSTALLER_MD5) \
	&& tar -I pigz -xvf docker/$(XIL_INSTALLER_TAR) -C docker

.PHONY: xilinx-config
xilinx-config: | docker/$(XIL_INSTALLER)
	docker/$(XIL_INSTALLER) --target ./docker/xilinx -- -b ConfigGen -l /xilinx \
	&& cp $$HOME/.Xilinx/install_config.txt ./docker/vivado_config.txt

#
# misc
#

.PHONY: cleanout
cleanout:
	rm -rf $(LINUX) \
		build-sw/*.bin \
		build-sw/*.elf \
		build-sw/*.ub \
		build-sw/*.dts \
		build-sw/*.dtb


.PHONY: cleanall
cleanall: cleansw cleanhw
	rm -rf verible.filelist

.PHONY: cleansw
cleansw:
	$(XIL_BASH) 'rm -rf build-sw \
		submodules/u-boot/arch/arm/dts/ultra96v2.dts \
		submodules/u-boot/configs/ultra96v2_defconfig \
		submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
		submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& git -C submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw checkout -- . \
	&& $(MAKE) -C submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src clean \
	&& $(MAKE) PLAT=zynqmp -C submodules/arm-trusted-firmware clean \
	&& $(MAKE) -C submodules/u-boot distclean \
	&& $(MAKE) -C submodules/linux distclean \
	&& $(MAKE) -C submodules/qemu-devicetrees clean'

.PHONY: cleanhw
cleanhw:
	rm -rf build-hw \
		*.log \
		*.jou \
		.Xil \
		*.html \
		*.xml \
		*.fst \
		*.hier \
		*.str \
		*.pb

build-hw build-sw build-sw/mount:
	mkdir -p $@
