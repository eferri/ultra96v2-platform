if { $argc < 6 } {
    puts "Expected args: <mode> <part> <debug> <waivers> <constraint file> <srcs>..."
    exit 1
}

set mode [lindex $argv 0]
set part [lindex $argv 1]
set debug [lindex $argv 2]
set waivers [lindex $argv 3]
set xdc [lindex $argv 4]
set srcs [lrange $argv 5 end]

source $waivers

# Vivado will lock BD IP if part isnt't set
set_part $part

read_bd build-hw/bd/zynqmp/zynqmp.bd

read_verilog -sv $srcs
read_xdc $xdc

set defines ""

if {$debug == "ila"} {
    set defines "-verilog_define DEBUG=1"
}

if {$mode == "synth"} {
    synth_design {*}[split $defines " "] -name zynqmp -top top -part $part
} elseif {$mode == "elab"} {
    synth_design {*}[split $defines " "] -rtl -name zynqmp -top top -part $part
} else {
    puts "Unexpected mode $mode"
    exit 1
}

write_verilog -force build-hw/synth_netlist.v
write_xdc -force -no_fixed_only build-hw/synth.xdc

if {$mode == "synth"} {
    report_timing -input_pins -warn_on_violation
    report_methodology
    report_utilization
    write_checkpoint -force build-hw/synth.dcp
} elseif {$mode == "elab"} {
    start_gui
}
