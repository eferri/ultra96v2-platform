
if { $argc != 1 } {
    puts "Expected args: <part>"
    exit 1
}

set part [lindex $argv 0]
source vivado/bd.tcl
