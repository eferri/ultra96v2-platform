# Load block design
open_checkpoint build-hw/synth.dcp

# create_debug_core ila_0 ila

# connect_debug_port ila_0/clk [get_nets clk]
# connect_debug_port ila_0/probe0 [get_nets reset]

# create_debug_port ila_0 probe
# set_property port_width 1 [get_debug_ports ila_0/clk]

opt_design

# Xilinx docs say this must be called immediately after opt_design
# write_debug_probes -force build-hw/system.ltx

place_design
phys_opt_design
route_design

report_methodology
report_timing_summary -warn_on_violation -no_detailed_paths

write_verilog -force build-hw/impl_netlist.v
write_xdc -force -no_fixed_only build-hw/impl.xdc
write_checkpoint -force build-hw/impl.dcp

write_bitstream -force build-hw/system.bit

close_design
