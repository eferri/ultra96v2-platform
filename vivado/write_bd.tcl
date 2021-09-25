
if { $argc != 2 } {
    puts "Expected args: <part> <board part>"
    exit 1
}

set part [lindex $argv 0]
set board_part [lindex $argv 1]
source vivado/bd.tcl
