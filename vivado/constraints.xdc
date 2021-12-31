
#RADIO_LED0 on FPGA / LED D9 / WiFi LED
set_property PACKAGE_PIN A9 [get_ports led_1]
#RADIO_LED1 on FPGA / LED D10 / Bluetooth LED
set_property PACKAGE_PIN B9 [get_ports led_2]

set_property PACKAGE_PIN F8 [get_ports uart_tx]
set_property PACKAGE_PIN F7 [get_ports uart_rx]

set_property IOSTANDARD LVCMOS18 [get_ports led_*]
set_property IOSTANDARD LVCMOS18 [get_ports uart_*]

set_output_delay -clock clk_pl_0 0 [get_ports led_1]
