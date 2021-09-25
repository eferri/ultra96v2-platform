connect

# Reset entire SOC
targets -set -filter {name =~ "PS TAP"}
rst -srst
after 500

# Disable Security gates to view PMU MB target
# By default, JTAGsecurity gates are enabled
# This disables security gates for DAP, PLTAP and PMU.
targets -set -filter {name =~ "PSU"}
mwr 0xffca0038 0x1ff
after 500

# Load and run PMU FW
targets -set -filter {name =~ "MicroBlaze PMU"}
dow build-sw/zynqmp_pmufw.elf
con
after 500

# Load bitstream to PL
targets -set -nocase -filter {name =~ "PL"}
fpga build-hw/system.bit
after 500

# Reset A53, load and run FSBL. This initializes PS and resets PL
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor -clear-registers
dow build-sw/zynqmp_fsbl.elf
con
# Give time for FSBL to run and reset PL
after 1000
