
if { $argc != 3} {
    puts "Expected args: <part> <debug> <bd_source_file>"
    exit 1
}

set part [lindex $argv 0]
set debug [lindex $argv 1]
set bd_source_file [lindex $argv 2]

set_part $part

source $bd_source_file

validate_bd_design
save_bd_design zynqmp

generate_target all [get_files $bd_out_file]

write_hw_platform -fixed -force -minimal build-hw/zynqmp.xsa
validate_hw_platform build-hw/zynqmp.xsa

close_bd_design zynqmp
