set ws_dir [file dirname [info script]]

hsi open_hw_design build-hw/zynqmp.xsa

hsi set_repo_path $ws_dir/../submodules/device-tree-xlnx

hsi create_sw_design device-tree -os device_tree -proc psu_cortexa53_0

hsi generate_target -dir $ws_dir/../device-tree

hsi close_hw_design [hsi current_hw_design]

file delete -force $ws_dir/../device-tree/include
file delete -force $ws_dir/../device-tree/device-tree.mss
