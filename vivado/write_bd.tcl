
if { $argc != 2} {
    puts "Expected args: <part> <bd_source_file>"
    exit 1
}

set part [lindex $argv 0]
set bd_source_file [lindex $argv 1]

set_part $part

source $bd_source_file

validate_bd_design
save_bd_design zynqmp

generate_target all [get_files $bd_out_file]

close_bd_design zynqmp

write_hw_platform -fixed -force build-hw/zynqmp.xsa
validate_hw_platform build-hw/zynqmp.xsa
