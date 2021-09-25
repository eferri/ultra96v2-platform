if { $argc < 3 } {
    puts "Expected args: <part> <board part> <srcs>"
    exit 1
}

set part [lindex $argv 0]
set board_part [lindex $argv 1]
set srcs [lrange $argv 2 end]

# Vivado will lock BD IP if part and board_part aren't set
set_part $part
set_property BOARD_PART $board_part [current_project]

read_bd build-hw/bd/zynqmp/zynqmp.bd

read_verilog -sv $srcs
read_xdc vivado/constraints.xdc

synth_design -name zynqmp -top top -part $part

write_verilog -force build-hw/synth_netlist.v
write_xdc -force -no_fixed_only build-hw/synth.xdc
write_checkpoint -force build-hw/synth.dcp
