### Synthesis

# zynqmp bd IP warnings
set_msg_config -severity WARNING -new_severity INFO -string "zynq_ultra_ps_e_v3_5_5"

# Typing undrivin pin to constant 0
set_msg_config -severity WARNING -new_severity INFO -id "Synth 8-3295"

# Parallel synthesis criteria not met
set_msg_config -severity WARNING -new_severity INFO -id "Synth 8-7080"

# Design has top port driven by constant
set_msg_config -severity WARNING -new_severity INFO -id "Synth 8-3917"

### Implementation

# See https://adaptivesupport.amd.com/s/question/0D54U00008SiFlESAV
set_msg_config -severity WARNING -new_severity INFO -id "Device 21-9073"
