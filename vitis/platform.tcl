if { $argc != 1 } {
    puts "Expected args: platform.tcl <xsa file>"
    exit 1
}

set xsa [file normalize [lindex $argv 0]]

set build_dir build-sw

file delete -force $build_dir/workspace
setws $build_dir/workspace

# Create platform and domain
platform create -name zynqmp_platform -hw $xsa -no-boot-bsp

# Create the FSBL Domain
domain create -name fsbl_domain -os standalone -proc psu_cortexa53_0 -arch 64-bit
bsp setlib xilffs
bsp setlib xilsecure
bsp setlib xilpm
bsp config stdin psu_uart_1
bsp config stdout psu_uart_1
bsp config zynqmp_fsbl_bsp true

# Create the PMU FW Domain
domain create -name pmufw_domain -os standalone -proc psu_pmu_0
bsp setlib xilfpga
bsp setlib xilsecure
bsp setlib xilskey
bsp config stdin psu_uart_1
bsp config stdout psu_uart_1

# Generate the platform
platform generate

# Create the applications
app create -name zynqmp_fsbl -template {Zynq MP FSBL} \
    -platform zynqmp_platform \
    -domain fsbl_domain \
    -sysproj zynqmp_system

app create -name zynqmp_pmufw -template {ZynqMP PMU Firmware} \
    -platform zynqmp_platform \
    -domain pmufw_domain \
    -sysproj zynqmp_system

# Configure the applications
app config -name zynqmp_fsbl build-config release

app config -name zynqmp_pmufw build-config release
app config -name zynqmp_pmufw define-compiler-symbols ENABLE_MOD_ULTRA96
app config -name zynqmp_pmufw define-compiler-symbols ULTRA96_VERSION=2

# Build the applications
app build -name zynqmp_fsbl
app build -name zynqmp_pmufw

file copy -force $build_dir/workspace/zynqmp_pmufw/Release/zynqmp_pmufw.elf $build_dir
file copy -force $build_dir/workspace/zynqmp_fsbl/Release/zynqmp_fsbl.elf $build_dir
