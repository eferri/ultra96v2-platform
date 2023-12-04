set ws_dir [file dirname [info script]]

source $ws_dir/write_bd.tcl

start_gui
open_bd_design build-hw/bd/zynqmp/zynqmp.bd
