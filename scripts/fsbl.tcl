hsi open_hw_design ./build-hw/zynqmp.xsa

file delete -force build-sw/fsbl

hsi generate_app -os standalone -proc psu_cortexa53_0 -app zynqmp_fsbl -sw fsbl -dir build-sw/fsbl

hsi close_hw_design [hsi current_hw_design]
