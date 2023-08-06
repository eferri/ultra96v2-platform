PFM_DIR ?= .

PART ?= xczu3eg-sbva484-1-e

#
# inputs
#

UID ?= 1000
GID ?= 1000
KVM_GID ?= 200

XIL_VERSION := 2023.1
XIL_INSTALLER := Xilinx_Unified_$(XIL_VERSION)_0507_1903
XIL_INSTALLER_TAR := $(XIL_INSTALLER).tar.gz
XIL_INSTALLER_MD5 := f2011ceba52b109e3551c1d3189a8c9c

BD_SRC ?= $(PFM_DIR)/vivado/default_bd.tcl

RTL_SRCS ?= \
	src/rtl/top.sv \
	src/rtl/flash.sv

SYNTH_SRCS ?= $(RTL_SRCS)

ALL_SRCS := $(RTL_SRCS)

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
DOCKER_ARGS := --project-directory . -f $(PFM_DIR)/docker-compose.yml
DOCKER_COMPOSE := docker compose $(DOCKER_ARGS)

DOCKER_RUN := $(DOCKER_COMPOSE) run --rm xil
DOCKER_RUN_ROOT := $(DOCKER_COMPOSE) run --user root --rm xil

DOCKER_BASH := $(DOCKER_RUN) bash -c
XIL_BASH := $(DOCKER_RUN) bash --rcfile /xilinx/Vitis/$(XIL_VERSION)/settings64.sh -ic

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
# Generate filelist for verible tools
#

SINGLE_LINE_SRCS := $(patsubst %,%,$(ALL_SRCS))

SRC_HASH = SRCS_$(shell echo '$($(1))' | md5sum | awk '{print $$1}')

verible.filelist: build-sim/$(call SRC_HASH,SINGLE_LINE_SRCS)
	rm -f $@
	echo $(SINGLE_LINE_SRCS) | sed 's/ /\n/g' > $@

build-sim/$(call SRC_HASH,SINGLE_LINE_SRCS): | build-sim
	rm -rf build-sw/SRCS*
	touch $@

#
# simulation
#

SIM_SRCS ?= \
	src/sim/tb.cpp

TOP ?= top
SIM_TOP := build-sim/V$(TOP)

SIM_EXE := build-sim/tb

VERILATOR_ARGS ?= \
	-O3 \
	-Wall \
	--verilate-jobs 0 \
	--threads $$(nproc) \
	--threads-dpi all \
	--timing \
	--trace-fst \
	--trace-threads 2 \
	--timescale 1ns/1ns \
	--top $(TOP) \
	--clk top.zynqmp.clk

.PHONY: sim
sim $(SIM_EXE): $(SIM_SRCS) | build-sim
	$(DOCKER_BASH) 'cd build-sim \
	&& cmake ../'

.PHONY: verilate
verilate $(SIM_TOP): verible.filelist | build-sim
	$(DOCKER_BASH) 'verilator $(VERILATOR_ARGS) --cc -Mdir ./build-sim $-f verible.filelist'

.PHONY: waves
waves:
	$(DOCKER_BASH) 'gtkwave'

.PHONY: lint
lint:
	$(DOCKER_BASH) 'verible-verilog-lint --ruleset all $(RTL_SRCS) \
	&& clang-tidy-15 $(SIM_SRCS)'

#
# vivado
#

VIVADO_ARGS := -nojournal -nolog

.PHONY: impl bit
impl bit $(IMPL) $(BIT): $(SYNTH) $(PFM_DIR)/vivado/bitstream.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/bitstream.tcl'

.PHONY: synth
synth $(SYNTH): $(PFM_DIR)/vivado/synth.tcl $(BD) $(PFM_DIR)/vivado/constraints.xdc $(SYNTH_SRCS) | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/synth.tcl -tclargs $(PART) $(SYNTH_SRCS)'

.PHONY: bd xsa
bd xsa $(BD) $(XSA): $(PFM_DIR)/vivado/write_bd.tcl $(PFM_DIR)/vivado/default_bd.tcl $(PFM_DIR)/vivado/zynqmp_preset.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/vivado/write_bd.tcl -tclargs $(PART) $(BD_SRC)'

# Interactive commands
.PHONY: vivado-shell
vivado-shell:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl'

.PHONY: vivado-gui
vivado-gui:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS)'

.PHONY: edit-bd
edit-bd: | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl -source $(PFM_DIR)/vivado/edit_bd.tcl -tclargs $(PART)'


#
# platform software
#

DTS_SRCS := \
	$(PFM_DIR)/device-tree/system-top.dts \
	$(PFM_DIR)/device-tree/pcw.dtsi \
	$(PFM_DIR)/device-tree/zynqmp-clk-ccf.dtsi \
	$(PFM_DIR)/device-tree/zynqmp.dtsi

# Generate dts and pm_cfg_obj from xsct

.PHONY: dts-gen
dts-gen: $(XSA) $(PFM_DIR)/scripts/dts.tcl
	$(XIL_BASH) 'xsct $(PFM_DIR)/scripts/dts.tcl'

.PHONY: dtb
dtb $(DTB) $(DTS): $(DTS_SRCS) | build-sw
	$(XIL_BASH) 'gcc -I device-tree -I $(PFM_DIR)/submodules/linux -E -nostdinc -undef \
					 -D__DTS__ -x assembler-with-cpp -o $(DTS) $(PFM_DIR)/device-tree/system-top.dts \
	&& dtc -I dts -O dtb -o $(DTB) $(DTS) \
	&& make -C $(PFM_DIR)/submodules/qemu-devicetrees \
	&& cp $(PFM_DIR)/submodules/qemu-devicetrees/LATEST/MULTI_ARCH/board-zynqmp-zcu102.dtb build-sw/qemu_system.dtb \
	&& cp $(PFM_DIR)/submodules/qemu-devicetrees/LATEST/MULTI_ARCH/zynqmp-pmu.dtb build-sw/qemu_pmu.dtb'

.PHONY: pmufw
pmufw $(PMUFW): | build-sw
	$(XIL_BASH) 'sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/misc/xparameters.h \
	&& $(MAKE) CFLAGS="-Os -flto -ffat-lto-objects -DULTRA96_VERSION=2 -DENABLE_MOD_ULTRA96 -DENABLE_SCHEDULER" \
		-C $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src \
	&& mb-objcopy -O binary $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf $(PMUFW) \
	&& cp $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.elf build-sw/zynqmp_pmufw.elf'

.PHONY: atf
atf $(ATF): | build-sw
	$(XIL_BASH) '$(MAKE) -j$$(nproc) CROSS_COMPILE=aarch64-none-elf- PLAT=zynqmp ZYNQMP_CONSOLE=cadence1 RESET_TO_BL31=1 all \
		-C $(PFM_DIR)/submodules/arm-trusted-firmware \
	&& cp $(PFM_DIR)/submodules/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf $(ATF)'

.PHONY: fsbl
fsbl $(FSBL): $(XSA) | build-sw
	$(XIL_BASH) 'xsct $(PFM_DIR)/scripts/fsbl.tcl \
	&& sed -i "s/_BASEADDRESS 0xFF000000/_BASEADDRESS 0xFF010000/g" $(PFM_DIR)/build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/include/xparameters.h \
	&& $(MAKE) -C build-sw/fsbl \
	&& cp build-sw/fsbl/executable.elf $(FSBL) \
	&& cp build-sw/fsbl/zynqmp_fsbl_bsp/psu_cortexa53_0/libsrc/xilpm_v5_0/src/pm_cfg_obj.c $(PFM_DIR)/bsp/pm_cfg_obj.c'

.PHONY: u-boot
u-boot $(U_BOOT): $(DTS) $(PFM_DIR)/bsp/ultra96v2_uboot_defconfig | build-sw
	$(XIL_BASH) 'mkdir -p $(PFM_DIR)/submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
	&& cp $(DTS) $(PFM_DIR)/submodules/u-boot/arch/arm/dts/ultra96v2.dts \
	&& cp $(PFM_DIR)/bsp/ultra96v2_uboot_defconfig $(PFM_DIR)/submodules/u-boot/configs/ultra96v2_defconfig \
	&& $(MAKE) -C $(PFM_DIR)/submodules/u-boot ultra96v2_defconfig \
	&& CROSS_COMPILE=aarch64-linux-gnu- $(MAKE) -j$$(nproc) -C $(PFM_DIR)/submodules/u-boot \
	&& cp $(PFM_DIR)/submodules/u-boot/u-boot.elf $(U_BOOT)'

.PHONY: linux
linux $(LINUX): $(PFM_DIR)/bsp/ultra96v2_linux_defconfig | build-sw
	$(XIL_BASH) 'cp $(PFM_DIR)/bsp/ultra96v2_linux_defconfig $(PFM_DIR)/submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& export CROSS_COMPILE=aarch64-linux-gnu- \
	&& $(MAKE) ARCH=arm64 -C $(PFM_DIR)/submodules/linux ultra96v2_defconfig \
	&& $(MAKE) ARCH=arm64 -j$$(nproc) -C $(PFM_DIR)/submodules/linux \
	&& cp $(PFM_DIR)/submodules/linux/arch/arm64/boot/Image $(LINUX)'

.PHONY: bin
bin $(BOOT_BIN): $(DTB) $(FSBL) $(PMUFW) $(ATF) $(U_BOOT) | build-sw
	$(XIL_BASH) 'bootgen -arch zynqmp -image $(PFM_DIR)/bsp/boot.bif -w -o $(BOOT_BIN)'

.PHONY: fit
fit $(FIT): $(LINUX) $(DTB) | build-sw
	$(XIL_BASH) 'mkimage -f $(PFM_DIR)/bsp/image.its $(FIT)'

.PHONY: rootfs
rootfs $(ROOTFS): | build-sw
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes \
	&& $(DOCKER_COMPOSE) build rootfs \
	&& docker export "$$(docker create --platform linux/arm64/v8 rootfs:latest)" -o ./build-sw/docker_rootfs.tar \
	&& $(XIL_BASH) -c ' \
	rm -rf ./build-sw/machine $(ROOTFS) ./build-sw/qemu.img \
	&& qemu-img create -f raw ./build-sw/qemu.img 1G \
	&& guestfish -f $(PFM_DIR)/scripts/guestfish_rootfs.sh \
	&& mkimage -A arm64 -C None -T script -d $(PFM_DIR)/bsp/qemu_boot.script ./build-sw/qemu_boot.scr'


.PHONY: rootfs-shell
rootfs-shell:
	$(DOCKER_COMPOSE) run --rm rootfs bash -i

.PHONY: qemu
qemu: $(U_BOOT) $(FIT) $(ROOTFS) $(ATF) $(PMUFW)
	$(XIL_BASH) '$(PFM_DIR)/scripts/qemu.sh'

#
# target
#

.PHONY: hw-debug
hw-debug:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source $(PFM_DIR)/scripts/debug.tcl'

.PHONY: boot
boot:
	$(XIL_BASH) 'xsdb -interactive $(PFM_DIR)/scripts/boot.tcl'

# SD card files to install
INSTALL_FILES := \
	$(BOOT_BIN) \
	$(FIT) \
	$(PFM_DIR)/bsp/extlinux

.PHONY: sd
sd: |
	$(PFM_DIR)/scripts/sd_utils.sh all $(INSTALL_FILES)

.PHONY: sd-mount
sd-mount: |
	$(PFM_DIR)/scripts/sd_utils.sh mount

.PHONY: sd-unmount
sd-unmount: |
	$(PFM_DIR)/scripts/sd_utils.sh unmount

.PHONY: sd-eject
sd-eject: |
	$(PFM_DIR)/scripts/sd_utils.sh eject

.PHONY: sd-partition
sd-partition: |
	$(PFM_DIR)/scripts/sd_utils.sh partition

#
# xinlinx installer
#

.PHONY: xilinx-extract
xilinx-extract docker/$(XIL_INSTALLER):
	md5sum $(PFM_DIR)/docker/$(XIL_INSTALLER_TAR) | grep $(XIL_INSTALLER_MD5) \
	&& tar -I pigz -xvf $(PFM_DIR)/docker/$(XIL_INSTALLER_TAR) -C docker

.PHONY: xilinx-config
xilinx-config: | docker/$(XIL_INSTALLER)
	$(PFM_DIR)/docker/$(XIL_INSTALLER) --target $(PFM_DIR)/docker/xilinx -- -b ConfigGen -l /xilinx \
	&& cp $$HOME/.Xilinx/install_config.txt $(PFM_DIR)/docker/xilinx_config.txt

#
# misc
#

.PHONY: cleansim
cleansim:
	rm -rf build-sim

.PHONY: cleansw
cleansw:
	rm -rf $(LINUX) \
		build-sw/*.bin \
		build-sw/*.elf \
		build-sw/*.ub \
		build-sw/*.dts \
		build-sw/*.dtb


.PHONY: cleanall
cleanall: cleansim cleanallsw cleanhw
	rm -rf verible.filelist

.PHONY: cleanallsw
cleanallsw:
	$(XIL_BASH) 'rm -rf build-sw \
		$(PFM_DIR)/submodules/u-boot/arch/arm/dts/ultra96v2.dts \
		$(PFM_DIR)/submodules/u-boot/configs/ultra96v2_defconfig \
		$(PFM_DIR)/submodules/u-boot/board/xilinx/zynqmp/ultra96v2 \
		$(PFM_DIR)/submodules/linux/arch/arm64/configs/ultra96v2_defconfig \
	&& sed -i "s/_BASEADDRESS 0xFF010000/_BASEADDRESS 0xFF000000/g" $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/misc/xparameters.h \
	&& $(MAKE) -C $(PFM_DIR)/submodules/embeddedsw/lib/sw_apps/zynqmp_pmufw/src clean \
	&& $(MAKE) PLAT=zynqmp -C $(PFM_DIR)/submodules/arm-trusted-firmware clean \
	&& $(MAKE) -C $(PFM_DIR)/submodules/u-boot distclean \
	&& $(MAKE) -C $(PFM_DIR)/submodules/linux distclean \
	&& $(MAKE) -C $(PFM_DIR)/submodules/qemu-devicetrees clean'

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

build-hw build-sw build-sw/mount build-sim:
	mkdir -p $@
