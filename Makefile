PART ?= xczu3eg-sbva484-1-i
BOARD_PART ?= avnet.com:ultra96v2:part0:1.2

#
# inputs
#

XIL_VERSION := 2022.2
XIL_INSTALLER := Xilinx_Unified_$(XIL_VERSION)_1014_8888
XIL_INSTALLER_TAR := $(XIL_INSTALLER).tar.gz
XIL_INSTALLER_MD5 := 4b4e84306eb631fe67d3efb469122671

RTL_SRCS ?= \
	rtl/flash.sv

SYNTH_SRCS ?= \
	$(RTL_SRCS) \
	rtl/top.sv

SIM_SRCS ?= \
	sim/tb.sv

#
# outputs
#

BIN := build-sw/BOOT.BIN
PMUFW := build-sw/zynqmp_pmufw.elf
FSBL := build-sw/zynqmp_fsbl.elf

SYSROOT := petalinux/images/linux/sdk/sysroots/aarch64-xilinx-linux

BIT := build-hw/system.bit
IMPL := build-hw/impl.dcp
SYNTH := build-hw/synth.dcp
XSA := build-hw/zynqmp.xsa
PETALINUX_XSA := petalinux/project-spec/hw-description/system.xsa
BD := build-hw/bd/zynqmp/zynqmp.bd

XSIM_EXEC := build-hw/sim/xsim/tb.sh


.PHONY: all
all: $(SIM_EXEC) $(XSIM_EXEC) $(BIN)

#
# docker
#

# Run command in bash shell with xilinx tools sourced
DOCKER_RUN := docker compose run --rm xil
XIL_BASH := $(DOCKER_RUN) bash -ic

PETALINUX_RUN := docker compose run --rm -w /app/petalinux xil
PETALINUX_BASH := $(PETALINUX_RUN) bash -ic

.PHONY: shell
shell:
	docker compose run --rm xil bash -i

.PHONY: docker
docker-image:
	docker compose up -d server \
	&& docker compose build --progress=tty \
		--build-arg XIL_VERSION=$(XIL_VERSION) \
		--build-arg XIL_INSTALLER=$(XIL_INSTALLER) \
		--build-arg XIL_INSTALLER_TAR=$(XIL_INSTALLER_TAR) \
		--build-arg XIL_INSTALLER_MD5=$(XIL_INSTALLER_MD5) \
	&& docker compose down

#
# linux
#

U_BOOT := build-linux/u-boot.elf
LINUX := build-linux/image.bin

.PHOHNY: u-boot
u-boot $(U_BOOT): | build-linux
	$(MAKE) -C submodules/u-boot

.PHOHNY: linux
linux $(LINUX): | build-linux
	$(MAKE) -C submodules/linux

#
# vivado / vitis
#

.PHONY: bin
bin $(BIN): $(PMUFW) $(FSBL) $(BIT)
	$(XIL_BASH) 'bootgen -arch zynqmp -image vitis/boot.bif -w -o $(BIN)'

.PHONY: fw
fw $(PMUFW) $(FSBL): $(XSA) vitis/platform.tcl | build-sw
	$(XIL_BASH) 'xsct vitis/platform.tcl $(XSA)'

VIVADO_ARGS := -nojournal -nolog

.PHONY: impl bit
impl bit $(IMPL) $(BIT): $(SYNTH) vivado/bitstream.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/bitstream.tcl'

.PHONY: synth
synth $(SYNTH): vivado/synth.tcl $(BD) vivado/constraints.xdc $(SYNTH_SRCS) | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/synth.tcl -tclargs $(PART) $(BOARD_PART) $(SYNTH_SRCS)'

.PHONY: bd xsa
bd xsa $(BD) $(XSA): vivado/write_bd.tcl vivado/bd.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/write_bd.tcl -tclargs $(PART) $(BOARD_PART)'

# Interactive commands
.PHONY: shell
vivado-shell:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl'

.PHONY: edit-bd
edit-bd: | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl -source vivado/edit_bd.tcl -tclargs $(PART) $(BOARD_PART)'


#
# petalinux
#

.PHONY: petalinux-xsa
petalinux-xsa $(PETALINUX_XSA): $(XSA)
	$(PETALINUX_BASH) 'petalinux-config --silentconfig --get-hw-description=../$(dir $(XSA))'

.PHONY: petalinux-build
petalinux-build: $(PETALINUX_XSA)
	$(PETALINUX_BASH) 'petalinux-build'

.PHONY: petalinux-package
petalinux-package:
	$(PETALINUX_BASH) 'petalinux-package --wic --wks project-spec/meta-avnet/recipes-core/images/avnet-image-minimal.wks'

.PHONY: sysroot
sysroot:
	$(PETALINUX_BASH) 'petalinux-build --sdk && petalinux-package --sysroot && touch $(SYSROOT)'

.PHONY: rootfs-config
rootfs-config: $(PETALINUX_XSA)
	$(PETALINUX_BASH) 'petalinux-config -c rootfs'

.PHONY: petalinux-config
petalinux-config: $(PETALINUX_XSA)
	$(PETALINUX_BASH) 'petalinux-config'

.PHONY: petalinux-clean
petalinux-clean:
	$(RM) -rf \
		petalinux/build \
		petalinux/images \
		petalinux/components \
		petalinux/project-spec/configs/*.old \
		petalinux/project-spec/hw-description/psu* project-spec/hw-description/*.xsa \
		petalinux/project-spec/hw-description/*.bit

#
# target
#

.PHONY: hw-debug
hw-debug:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source scripts/debug.tcl'

.PHONY: boot
boot:
	$(XIL_BASH) 'xsdb scripts/boot.tcl'

# SD card files to install
INSTALL_FILES += build-sw/BOOT.BIN

.PHONY: sd
sd:
	$(DOCKER_RUN) ./scripts/sd_utils.sh all $(INSTALL_FILES)

#
# xinlinx installer
#

.PHONY: xil-extract
xil-extract static/$(XIL_INSTALLER):
	md5sum static/${XIL_INSTALLER_TAR} | grep ${XIL_INSTALLER_MD5} \
	&& tar -I pigz -xvf static/$(XIL_INSTALLER_TAR) -C static

 .PHONY: vitis-install-config
vitis-config: | static/$(XIL_INSTALLER)
	static/$(XIL_INSTALLER)/xsetup -b ConfigGen -l /xilinx \
	&& cp $$HOME/.Xilinx/install_config.txt docker/vitis_config.txt

 .PHONY: petalinux-install-config
petalinux-install-config: | static/$(XIL_INSTALLER)
	static/$(XIL_INSTALLER)/xsetup -b ConfigGen -l /xilinx \
	&& cp $$HOME/.Xilinx/install_config.txt docker/petalinux_config.txt

#
# simulation
#

.PHONY: sim
sim: $(SIM_EXEC)
	$(DOCKER_RUN) $(SIM_EXEC)

.PHONY: waves
waves:
	$(DOCKER_RUN) gtkwave waves.fst

.PHOHNY: xsim
xsim:
	$(XIL_BASH) 'cd build-hw/sim/xsim && ./tb.sh'

.PHOHNY: xsim-build
xsim-build $(XSIM_EXEC): $(BD) $(SIM_SRCS) $(SYNTH_SRCS)
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/xsim.tcl -tclargs $(PART) $(BOARD_PART) $(SIM_SRCS) $(SYNTH_SRCS)'

.PHOHNY: xsim-clean
xsim-clean:
	$(XIL_BASH) 'cd build-hw/sim/xsim && ./tb.sh -reset_run'

.PHONY: xsim-waves
xsim-waves:
	$(DOCKER_RUN) gtkwave build-hw/sim/xsim/waves.vcd

#
# misc
#

.PHONY: cleanall
cleanall: petalinux-clean
	rm -rf static/$(XIL_INSTALLER) \
		build* \
		*.log \
		*.jou \
		.Xil \
		*.html \
		*.xml \
		*.fst \
		*.hier \
		*.str \
		*.pb \
		tight_setup_hold_pins.txt

build-hw build-sw build-sim build-linux:
	mkdir -p $@
