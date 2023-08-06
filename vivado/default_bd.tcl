
set ws_dir [file dirname [info script]]

set_property TARGET_LANGUAGE Verilog [current_project]

# Create block design
file delete -force build-hw/bd
create_bd_design -dir build-hw/bd zynqmp
set bd_out_file build-hw/bd/zynqmp/zynqmp.bd

# Blocks
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynqmp

set user_config [ list \
    CONFIG.PSU__USE__IRQ0 {0} \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
]

set preset_config [ source $ws_dir/zynqmp_preset.tcl ]

set config [ concat $preset_config $user_config ]

set_property -dict "$config" [get_bd_cells zynqmp]

# Ports
create_bd_port -dir O reset
create_bd_port -dir O clk

connect_bd_net [get_bd_ports clk] [get_bd_pins zynqmp/pl_clk0]
connect_bd_net [get_bd_ports reset] [get_bd_pins zynqmp/pl_resetn0]
