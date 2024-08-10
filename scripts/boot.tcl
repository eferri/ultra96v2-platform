connect

# Reset entire SOC
targets -set -filter {name =~ "PS TAP"}
rst -srst
after 500

# Disable Security gates to view PMU MB target
# By default, JTAGsecurity gates are enabled
# This disables security gates for DAP, PLTAP and PMU.
targets -set -filter {name =~ "PSU"}
mask_write 0xffca0038 0x1c0 0x1c0
after 500

# Load and run PMU FW
targets -set -filter {name =~ "MicroBlaze PMU"}
dow "build-sw/zynqmp_pmufw.elf"
con
after 500

targets -set -filter {name =~ "PSU"}
mask_write 0xffca0038 0x1c0 0x0

# Load bitstream to PL
targets -set -nocase -filter {name =~ "PL"}
fpga build-hw/fpga.bit
after 500

# Reset A53, load and run FSBL. This initializes PS and resets PL
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor -clear-registers
dow "build-sw/zynqmp_fsbl.elf"
con
# Give time for FSBL to run and reset PL
after 1000

# dow -data "build-sw/system.dtb" 0x100000
# after 100

# dow "build-sw/u-boot.elf"
# after 100

# dow "build-sw/bl31.elf"
# after 100

# dow -data  "build-sw/image.ub" 0x10000000

# con

exit 0
