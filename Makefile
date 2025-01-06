#
# inputs
#

export PFM_DIR ?= .

UID ?= 1000
GID ?= 1000
KVM_GID ?= 200

SD_DEV ?= sda
BD_SRC ?= $(PFM_DIR)/vivado/default_bd.tcl
CONSTRAINTS ?= $(PFM_DIR)/vivado/constraints.xdc
WAIVERS ?= $(PFM_DIR)/vivado/waivers.tcl
VERILOG_SRCS ?= $(shell cat $(PFM_DIR)/sources.f | sed -e 's|src|$(PFM_DIR)/src|' | sed -e 's/\n/ /')
SYNTH_SRCS ?= $(filter-out $(PFM_DIR)/src/rtl/zynqmp.sv $(PFM_DIR)/src/sim/%, $(VERILOG_SRCS))
TOP_MODULE ?= tb
DEBUG_DESIGN ?= no

PART ?= xczu3eg-sbva484-1-e

export XIL_VERSION := 2024.2

XIL_INSTALLER := FPGAs_AdaptiveSoCs_Unified_$(XIL_VERSION)_1113_1001
XIL_INSTALLER_TAR := $(XIL_INSTALLER).tar
XIL_INSTALLER_MD5 :=  0ca31a787bbdff82b55213522e604446

#
# outputs
#

# bsp
DTS := build-sw/system.dts
DTB := build-sw/system.dtb

ATF := build-sw/bl31.elf
PMUFW := build-sw/zynqmp_pmufw.bin

BOOT_BIN := build-sw/BOOT.bin
SPL_BOOT_BIN := build-sw/boot.bin
FSBL := build-sw/zynqmp_fsbl.elf
PM_CFG_OBJ := build-sw/pm_cfg_obj.bin
U_BOOT := build-sw/u-boot.elf
U_BOOT_ITB := build-sw/u-boot.itb
LINUX := build-sw/Image
FIT := build-sw/image.ub

ROOTFS := build-sw/rootfs.tar.gz

# fpga
BIT := build-hw/fpga.bin
IMPL := build-hw/impl.dcp
SYNTH := build-hw/synth.dcp
XSA := build-hw/zynqmp.xsa
BD := build-hw/bd/zynqmp/zynqmp.bd


.PHONY: all
all: $(BIT) $(BOOT_BIN) $(FIT) $(ROOTFS)

#
# docker
#

# Run command in bash shell with xilinx tools sourced
DOCKER_COMPOSE := docker compose --project-directory . -f $(PFM_DIR)/docker-compose.yml

DOCKER_RUN := $(DOCKER_COMPOSE) run --rm xil
DOCKER_RUN_ROOT := $(DOCKER_COMPOSE) run --user root --rm xil

XIL_BASH := $(DOCKER_RUN) bash -ic

.PHONY: shell
shell:
	$(DOCKER_RUN) bash -i

.PHONY: root-shell
root-shell:
	$(DOCKER_RUN_ROOT) bash -i

.PHONY: docker
docker-image: $(XILINX_TOKEN)
	docker compose -f $(PFM_DIR)/docker-compose.yml up -d server \
	&& docker compose -f $(PFM_DIR)/docker-compose.yml \
		--project-directory $(PFM_DIR) \
		--progress=plain build xil \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg KVM_GID=$(KVM_GID) \
		--build-arg XIL_VERSION=$(XIL_VERSION) \
		--build-arg XIL_INSTALLER=$(XIL_INSTALLER) \
		--build-arg XIL_INSTALLER_TAR=$(XIL_INSTALLER_TAR) \
		--build-arg XIL_INSTALLER_MD5=$(XIL_INSTALLER_MD5) \
	&& docker compose -f $(PFM_DIR)/docker-compose.yml down

#
# simulation
#

.PHONY: sim
sim:
	$(XIL_BASH) 'cmake --preset=release \
	&& cmake --build --preset=release \
	&& ./build-sim/release/src/sim_exec'

.PHONY: sim-debug
sim-debug:
	$(XIL_BASH) 'cmake --preset=dev \
	&& cmake --build --preset=dev'

.PHONY: waves
waves:
	$(XIL_BASH) 'gtkwave \
		--dump=build-sim/sim.fst \
		--save=debug.gtkw \
		--rcfile=.gtkwaverc'

.PHONY: lint
lint: sim-debug
	$(XIL_BASH) 'shopt -s globstar \
	&& verible-verilog-lint --ruleset all --rules_config_search $(VERILOG_SRCS) \
	&& clang-tidy -p build-sim/dev src/**/*.cpp'

#
# vivado
#

VIVADO_ARGS := -nojournal -nolog

.PHONY: bit
bit $(IMPL) $(BIT): $(SYNTH) $(PFM_DIR)/vivado/bitstream.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/bitstream.tcl -tclargs $(DEBUG_DESIGN) $(WAIVERS)'

.PHONY: synth
synth $(SYNTH): $(BD) $(SYNTH_SRCS) $(CONSTRAINTS) $(PFM_DIR)/vivado/synth.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/synth.tcl -tclargs synth $(PART) $(DEBUG_DESIGN) $(WAIVERS) $(CONSTRAINTS) $(SYNTH_SRCS)'

.PHONY: elab
elab: $(BD) $(SYNTH_SRCS) $(CONSTRAINTS) $(PFM_DIR)/vivado/synth.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/synth.tcl -tclargs elab $(PART) $(DEBUG_DESIGN) $(WAIVERS) $(CONSTRAINTS) $(SYNTH_SRCS)'

.PHONY: bd xsa
bd xsa $(BD) $(XSA): $(PFM_DIR)/vivado/write_bd.tcl $(BD_SRC) $(PFM_DIR)/vivado/zynqmp_preset.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/write_bd.tcl -tclargs $(PART) $(DEBUG_DESIGN) $(BD_SRC)'

# Interactive commands
.PHONY: vivado-shell
vivado-shell:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl'

.PHONY: vivado-gui
vivado-gui:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS)'

.PHONY: edit-bd
edit-bd: | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl -source $(PFM_DIR)/vivado/edit_bd.tcl -tclargs $(PART) $(DEBUG_DESIGN) $(BD_SRC)'


#
# platform software
#

DTS_SRCS := \
	$(PFM_DIR)/device-tree/system-top.dts \
	$(PFM_DIR)/device-tree/pcw.dtsi \
	$(PFM_DIR)/device-tree/zynqmp-clk-ccf.dtsi \
	$(PFM_DIR)/device-tree/zynqmp.dtsi

# Generate dts from xsct

.PHONY: dts-gen
dts-gen: $(XSA) $(PFM_DIR)/scripts/dts.tcl
	$(XIL_BASH) 'xsct $(PFM_DIR)/scripts/dts.tcl'

.PHONY: dtb
dtb $(DTB) $(DTS): $(DTS_SRCS) | build-sw
	$(XIL_BASH) 'gcc -I device-tree -I $(PFM_DIR)/submodules/linux -I $(PFM_DIR)/submodules/linux/include \
		-E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o $(DTS) $(PFM_DIR)/device-tree/system-top.dts \
	&& dtc -I dts -O dtb -o $(DTB) $(DTS)'

.PHONY: pmufw
pmufw $(PMUFW): | build-sw
	$(XIL_BASH) 'sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/misc/xparameters.h \
	&& $(MAKE) CFLAGS="-Os -flto -ffat-lto-objects -DULTRA96_VERSION=2 -DENABLE_MOD_ULTRA96 -DENABLE_SCHEDULER" \
		-C $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src \
	&& mb-objcopy -O binary $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf $(PMUFW) \
	&& cp $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf build-sw/zynqmp_pmufw.elf'

.PHONY: atf
atf $(ATF): | build-sw
	$(XIL_BASH) '$(MAKE) -j$$(nproc) CROSS_COMPILE=aarch64-none-elf- PLAT=zynqmp ZYNQMP_CONSOLE=cadence1 RESET_TO_BL31=1 bl31 \
		-C $(PFM_DIR)/submodules/arm-trusted-firmware \
	&& cp $(PFM_DIR)/submodules/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf $(ATF) \
	&& cp $(PFM_DIR)/submodules/arm-trusted-firmware/build/zynqmp/release/bl31.bin build-sw/bl31.bin'

.PHONY: pm_cfg_obj
pm_cfg_obj $(PM_CFG_OBJ): $(XSA) $(PFM_DIR)/scripts/fsbl.tcl | build-sw
	$(XIL_BASH) 'xsct $(PFM_DIR)/scripts/fsbl.tcl \
	&& cp build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/libsrc/xilpm_v5_3/src/pm_cfg_obj.c build-sw/pm_cfg_obj.c \
	&& $(PFM_DIR)/submodules/u-boot/tools/zynqmp_pm_cfg_obj_convert.py build-sw/pm_cfg_obj.c build-sw/pm_cfg_obj.bin'

.PHONY: fsbl
fsbl $(FSBL): $(XSA) $(PFM_DIR)/scripts/fsbl.tcl | build-sw
	$(XIL_BASH) 'xsct $(PFM_DIR)/scripts/fsbl.tcl \
	&& sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/include/xparameters.h \
	&& $(MAKE) -C build-sw/fsbl \
	&& cp build-sw/fsbl/executable.elf $(FSBL)'

.PHONY: u-boot
u-boot $(U_BOOT) $(SPL_BOOT_BIN): $(PMUFW) $(ATF) $(PM_CFG_OBJ) $(DTS) $(PFM_DIR)/bsp/ultra96v2_uboot_defconfig | build-sw
	$(XIL_BASH) 'mkdir -p $(PFM_DIR)/submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
	&& cp $(DTS) $(PFM_DIR)/submodules/u-boot/arch/arm/dts/ultra96v2.dts \
	&& cp $(PFM_DIR)/bsp/ultra96v2_uboot_defconfig $(PFM_DIR)/submodules/u-boot/configs/ultra96v2_defconfig \
	&& export BL31=/app/build-sw/bl31.bin \
	&& $(MAKE) -C $(PFM_DIR)/submodules/u-boot ultra96v2_defconfig \
	&& CROSS_COMPILE=aarch64-linux-gnu- $(MAKE) -j$$(nproc) -C $(PFM_DIR)/submodules/u-boot \
	&& cp $(PFM_DIR)/submodules/u-boot/u-boot.elf $(U_BOOT) \
	&& cp $(PFM_DIR)/submodules/u-boot/u-boot.itb $(U_BOOT_ITB) \
	&& cp $(PFM_DIR)/submodules/u-boot/spl/u-boot-spl.bin build-sw/u-boot-spl.bin \
	&& cp $(PFM_DIR)/submodules/u-boot/spl/u-boot-spl build-sw/u-boot-spl.elf \
	&& cp $(PFM_DIR)/submodules/u-boot/spl/boot.bin $(SPL_BOOT_BIN)'

.PHONY: linux
linux $(LINUX): $(PFM_DIR)/bsp/ultra96v2_linux_defconfig | build-sw
	$(XIL_BASH) 'cp $(PFM_DIR)/bsp/ultra96v2_linux_defconfig $(PFM_DIR)/submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& export CROSS_COMPILE=aarch64-linux-gnu- \
	&& $(MAKE) ARCH=arm64 -C $(PFM_DIR)/submodules/linux ultra96v2_defconfig \
	&& $(MAKE) ARCH=arm64 -j$$(nproc) -C $(PFM_DIR)/submodules/linux \
	&& cp $(PFM_DIR)/submodules/linux/arch/arm64/boot/Image $(LINUX)'

.PHONY: boot_bin
boot_bin $(BOOT_BIN): $(DTB) $(FSBL) $(PMUFW) $(ATF) $(U_BOOT) $(PFM_DIR)/bsp/boot.bif | build-sw
	$(XIL_BASH) 'bootgen -arch zynqmp -image $(PFM_DIR)/bsp/boot.bif -w -o $(BOOT_BIN)'

.PHONY: fit_image
fit_image $(FIT): $(LINUX) $(DTB) $(PFM_DIR)/bsp/image.its | build-sw
	$(XIL_BASH) 'mkimage -f $(PFM_DIR)/bsp/image.its $(FIT)'

.PHONY: rootfs
rootfs $(ROOTFS): | build-sw
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes \
	&& docker compose -f $(PFM_DIR)/docker-compose.yml --progress=plain --project-directory $(PFM_DIR) build rootfs \
	&& docker export "$$(docker create --platform linux/arm64/v8 rootfs:latest)" -o ./build-sw/docker_rootfs.tar \
	&& $(XIL_BASH) -c ' \
	rm -rf ./build-sw/machine $(ROOTFS) ./build-sw/qemu.img \
	&& qemu-img create -f raw ./build-sw/qemu.img 1G \
	&& guestfish -f $(PFM_DIR)/scripts/guestfish_rootfs.sh \
	&& mkimage -A arm64 -C None -T script -d $(PFM_DIR)/bsp/qemu_boot.script ./build-sw/qemu_boot.scr'

.PHONY: rootfs-shell
rootfs-shell:
	$(DOCKER_COMPOSE) run --rm rootfs bash -i

#
# target
#

.PHONY: hw-debug
hw-debug:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/debug.tcl'

.PHONY: fpgautil
fpgautil:
	scp $(BIT) ultra96v2:~ \
	&& ssh ultra96v2 fpgautil $(notdir $(BIT))

.PHONY: boot
boot:
	$(XIL_BASH) 'xsdb -interactive $(PFM_DIR)/scripts/boot.tcl'

# Files to install on SD card FAT32 partition
INSTALL_FILES := \
	$(BOOT_BIN) \
	$(FIT) \
	$(PFM_DIR)/bsp/extlinux

INSTALL_FILES_SPL := \
	$(SPL_BOOT_BIN) \
	$(U_BOOT_ITB) \
	$(FIT) \
	$(PFM_DIR)/bsp/extlinux

.PHONY: sd
sd: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) all $(INSTALL_FILES)

.PHONY: sd-spl
sd-spl: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) all $(INSTALL_FILES_SPL)

.PHONY: sd-mount
sd-mount: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) mount

.PHONY: sd-unmount
sd-unmount: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) unmount

.PHONY: sd-eject
sd-eject: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) eject

.PHONY: sd-partition
sd-partition: |
	$(PFM_DIR)/scripts/sd_utils.sh $(SD_DEV) partition

#
# xinlinx installer
#

.PHONY: xilinx-extract
xilinx-extract $(PFM_DIR)/docker/$(XIL_INSTALLER):
	md5sum $(PFM_DIR)/docker/$(XIL_INSTALLER_TAR) | grep $(XIL_INSTALLER_MD5) \
	&& tar -xvf $(PFM_DIR)/docker/$(XIL_INSTALLER_TAR) -C $(PFM_DIR)/docker

.PHONY: xilinx-config
xilinx-config: | $(PFM_DIR)/docker/$(XIL_INSTALLER)
	$(PFM_DIR)/docker/$(XIL_INSTALLER)/xsetup -b ConfigGen -l /xilinx \
	&& cp $$HOME/.Xilinx/install_config.txt $(PFM_DIR)/docker/xilinx_config.txt

#
# misc
#

.PHONY: cleansim
cleansim:
	rm -rf build-sim

.PHONY: cleansw
cleansw:
	rm -rf build-sw

.PHONY: cleanhw
cleanhw:
	rm -rf build-hw \
		*.log \
		*.jou \
		.Xil \
		*.html \
		*.xml \
		*.str \
		*.pb \
		clockInfo.txt

.PHONY: cleannested
cleannested:
	$(XIL_BASH) 'rm -rf $(PFM_DIR)/submodules/u-boot/arch/arm/dts/ultra96v2.dts \
		$(PFM_DIR)/submodules/u-boot/configs/ultra96v2_defconfig \
		$(PFM_DIR)/submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
		$(PFM_DIR)/submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& git -C $(PFM_DIR)/submodules/embeddedsw checkout . \
	&& $(MAKE) -C $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src clean \
	&& $(MAKE) PLAT=zynqmp -C $(PFM_DIR)/submodules/arm-trusted-firmware clean \
	&& $(MAKE) -C $(PFM_DIR)/submodules/u-boot distclean \
	&& $(MAKE) -C $(PFM_DIR)/submodules/linux distclean'

.PHONY: cleanall
cleanall: cleansim cleansw cleanhw cleannested

build-hw build-sw build-sw/mount build-sim:
	mkdir -p $@
