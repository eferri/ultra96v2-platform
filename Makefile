PART := xczu3eg-sbva484-1-i
BOARD_PART := avnet.com:ultra96v2:part0:1.2

XIL_INSTALLER := Xilinx_Unified_2021.2_1021_0703
XIL_INSTALLER_FILE := $(XIL_INSTALLER).tar.gz
XIL_INSTALLER_MD5 := c6f91186f332528a7b74a6a12a759fb6

RTL_SRCS := \
	rtl/up_counter.sv

SYNTH_SRCS := \
	$(RTL_SRCS) \
	rtl/top.sv

VERILATOR_SRCS := \
	sim/tb.cpp \
	sim/verilator_top.sv

SIM_SRCS := \
	sim/tb.sv

# Run command in bash shell with xilinx tools sourced
DOCKER_RUN := docker compose run --rm xil
XIL_BASH := $(DOCKER_RUN) bash -ic

.PHONY: shell
shell:
	docker compose run --rm xil bash -i

.PHONY: docker
docker-image:
	docker compose up -d server && \
	docker compose build --progress=tty \
		--build-arg XIL_INSTALLER=$(XIL_INSTALLER) \
		--build-arg XIL_INSTALLER_MD5=$(XIL_INSTALLER_MD5) && \
	docker compose down

# ----------------------------- Vivado/Vitis ------------------------------------

BIN := build-sw/BOOT.BIN
PMUFW := build-sw/zynqmp_pmufw.elf
FSBL := build-sw/zynqmp_fsbl.elf

BIT := build-hw/system.bit
IMPL := build-hw/impl.dcp
SYNTH := build-hw/synth.dcp
XSA := build-hw/zynqmp.xsa
BD := build-hw/bd/zynqmp/zynqmp.bd

SIM_EXEC := build-verilator/sim
XSIM_EXEC := build-hw/sim/xsim/tb.sh

.PHONY: all
all: $(SIM_EXEC) $(XSIM_EXEC) $(BIN)

.PHONY: bin
bin $(BIN): $(PMUFW) $(FSBL) $(BIT)
	$(XIL_BASH) 'bootgen -arch zynqmp -image vitis/boot.bif -w -o $(BIN)'

.PHONY: fw
fw $(PMUFW) $(FSBL): $(XSA) vitis/platform.tcl | build-sw
	$(XIL_BASH) 'xsct vitis/platform.tcl $(XSA)'

VIVADO_ARGS := -nojournal -nolog

.PHONY: impl
impl $(IMPL) $(BIT): $(SYNTH) vivado/bitstream.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/bitstream.tcl'

.PHONY: synth
synth $(SYNTH): vivado/synth.tcl $(BD) vivado/constraints.xdc $(SYNTH_SRCS) | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/synth.tcl -tclargs $(PART) $(BOARD_PART) $(SYNTH_SRCS)'

.PHONY: bd
bd $(BD) $(XSA): vivado/write_bd.tcl vivado/bd.tcl | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode batch -source vivado/write_bd.tcl -tclargs $(PART) $(BOARD_PART)'

# Interactive commands
.PHONY: shell
vivado-shell:
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl'

.PHONY: edit-bd
edit-bd: | build-hw
	$(XIL_BASH) 'vivado $(VIVADO_ARGS) -mode tcl -source vivado/edit_bd.tcl -tclargs $(PART) $(BOARD_PART)'

# ------------------------------- Target ------------------------------------------

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

# ----------------------------- Xilinx Config -------------------------------------

.PHONY: xil-extract
xil-extract $(XIL_INSTALLER): | static
	md5sum static/${XIL_INSTALLER_FILE} | grep ${XIL_INSTALLER_MD5} && \
	tar -xvf static/$(XIL_INSTALLER_FILE) -C static

 .PHONY: xil-config
xil-config: | $(XIL_INSTALLER) static
	static/$(XIL_INSTALLER)/xsetup -b ConfigGen -l /xilinx && \
	cp $$HOME/.Xilinx/install_config.txt docker

# ------------------------------ Simulation -----------------------------------

VERILATOR_ARGS := -sv --cc --exe --top verilator_top -Wall --trace-fst \
				 --timescale 1ns/1ns --threads $$(nproc) --trace-threads $$(nproc) \
				 -MAKEFLAGS -j$$(nproc) -Mdir build-verilator -o sim

.PHONY: verilate
verilate $(SIM_EXEC): $(VERILATOR_SRCS) $(RTL_SRCS) | build-verilator
	$(XIL_BASH) 'verilator $(VERILATOR_ARGS) --build $(VERILATOR_SRCS) $(RTL_SRCS)'

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

.PHONY: cleanall
cleanall:
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
		*.pb

build-hw build-sw build-sim build-verilator static:
	mkdir -p $@
