if { $argc < 2 } {
    puts "Expected args: <part> <srcs>"
    exit 1
}

set part [lindex $argv 0]
set srcs [lrange $argv 1 end]

# Vivado will lock BD IP if part isnt't set
set_part $part

read_bd build-hw/bd/zynqmp/zynqmp.bd

read_verilog -sv $srcs
read_xdc vivado/constraints.xdc

set_msg_config -suppress -severity WARNING -string "zynq_ultra_ps_e_v3_5_0"
set_msg_config -suppress -severity WARNING -id "Synth 8-3295"

synth_design -name zynqmp -top top -part $part

write_verilog -force build-hw/synth_netlist.v
write_xdc -force -no_fixed_only build-hw/synth.xdc
write_checkpoint -force build-hw/synth.dcp
