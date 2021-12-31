
if {![info exists part] || ![info exists board_part]} {
    puts "set \"part\" and \"board_part\" before sourcing script\n"
    exit 1
}

set_part $part
set_property BOARD_PART $board_part [current_project]
set_property SIMULATOR_LANGUAGE Verilog [current_project]
set_property TARGET_LANGUAGE Verilog [current_project]

# Create block design
file delete -force build-hw/bd
create_bd_design -dir build-hw/bd zynqmp
set bd_file build-hw/bd/zynqmp/zynqmp.bd

# Blocks
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynqmp
set_property SELECTED_SIM_MODEL rtl [get_bd_cells zynqmp]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynqmp]

set_property -dict [ list \
    CONFIG.PSU__PMU__GPO2__POLARITY {high} \
    CONFIG.PSU__USE__IRQ0 {0} \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
    CONFIG.PSU__SPI0__GRP_SS1__ENABLE {1} \
    CONFIG.PSU__SPI0__GRP_SS2__ENABLE {1} \
    CONFIG.PSU_MIO_25_PULLUPDOWN {pullup} \
] [get_bd_cells zynqmp]

# Ports
create_bd_port -dir O reset
create_bd_port -dir O clk

connect_bd_net [get_bd_ports clk] [get_bd_pins zynqmp/pl_clk0]
connect_bd_net [get_bd_ports reset] [get_bd_pins zynqmp/pl_resetn0]

validate_bd_design
save_bd_design zynqmp

file delete -force build-hw/ip-user build-hw/ip-static
set_property SYNTH_CHECKPOINT_MODE None [get_files $bd_file]

generate_target all [get_files $bd_file]
export_ip_user_files -no_script -of_objects [get_files $bd_file] \
    -ip_user_files_dir build-hw/ip-user \
    -ipstatic_source_dir build-hw/ip-static

file delete -force .ip_user_files

close_bd_design zynqmp

write_hw_platform -fixed -force build-hw/zynqmp.xsa
validate_hw_platform build-hw/zynqmp.xsa

