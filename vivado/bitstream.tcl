if { $argc != 2 } {
    puts "Expected args: <debug> <waivers> ..."
    exit 1
}

set debug [lindex $argv 0]
set waivers [lindex $argv 1]

source $waivers

# Load block design
open_checkpoint build-hw/synth.dcp

opt_design

if {$debug == "ila"} {
    # Xilinx docs say this must be called immediately after opt_design
    write_debug_probes -force build-hw/zynqmp.ltx
}

power_opt_design

place_design
phys_opt_design
route_design

report_timing -input_pins -warn_on_violation
report_methodology
report_utilization

write_verilog -force build-hw/impl_netlist.v
write_xdc -force -no_fixed_only build-hw/impl.xdc
write_checkpoint -force build-hw/impl.dcp

write_bitstream -force -bin_file build-hw/fpga.bit

close_design
