open_hw_manager
connect_hw_server
open_hw_target

set_property PROBES.FILE build-hw/zynqmp.ltx [current_hw_device]
set_property PROGRAM.FILE build-hw/fpga.bit [current_hw_device]

program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]

start_gui
