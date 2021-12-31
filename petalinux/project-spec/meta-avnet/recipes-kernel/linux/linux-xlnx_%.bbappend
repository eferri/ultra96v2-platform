FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://bsp.cfg \
            file://user.cfg \
            file://vitis_kconfig.cfg \
            file://0001-hwmon-pmbus-Add-Infineon-IR38060-62-63-driver.patch \
            "

SRC_URI:append:u96v2-sbc = " file://fix_u96v2_pwrseq_simple.patch \
                           "
