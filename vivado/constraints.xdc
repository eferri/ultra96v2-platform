
#RADIO_LED0 on FPGA / LED D9 / WiFi LED
set_property PACKAGE_PIN A9 [get_ports led_1]

#RADIO_LED1 on FPGA / LED D10 / Bluetooth LED
set_property PACKAGE_PIN B9 [get_ports led_2]

set_property IOSTANDARD LVCMOS18 [get_ports led_*]
