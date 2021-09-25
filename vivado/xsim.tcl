if { $argc < 3 } {
    puts "Expected args: <part> <board part> <srcs>"
    exit 1
}

set part [lindex $argv 0]
set board_part [lindex $argv 1]
set srcs [lrange $argv 2 end]

set bd_file build-hw/bd/zynqmp/zynqmp.bd

# Vivado will lock BD IP if part and board_part aren't set
set_part $part
set_property BOARD_PART $board_part [current_project]

read_bd $bd_file
# This fixes warning about bd being out of date. Seems like a bug ...
generate_target all [get_files $bd_file]

add_files -fileset sim_1 -norecurse sim/tb.sv $srcs
set_property top tb [get_filesets sim_1]

file delete -force build-hw/sim

export_simulation -force -of_objects [get_filesets sim_1] -simulator xsim \
    -absolute_path \
    -directory build-hw/sim \
    -ip_user_files_dir build-hw/ip-user \
    -ipstatic_source_dir build-hw/ip-static \
    -use_ip_compiled_libs \
    -more_options {
        {xsim.elaborate.xelab: -timescale 1ns/1ps -override_timeunit -override_timeprecision}
    }
