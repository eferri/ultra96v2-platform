require recipes-core/images/petalinux-image-common.inc

# append what is already defined by petalinux (build/conf/plnxtool.conf)
# this will include what the user adds or removes via "petalinux-config -c rootfs"
IMAGE_INSTALL:append= "\
        ${IMAGE_INSTALL:pn-petalinux-image-minimal} \
"

IMAGE_INSTALL:append:u96v2-sbc = "\
        bc \
        bonnie++ \
        coreutils \
        ethtool \
        fpga-manager-script \
        haveged \
        hdparm \
        hellopm \
        i2c-tools \
        i2c-tools-misc \
        iperf3 \
        kernel-modules \
        nano \
        openssh \
        openssh-scp \
        openssh-sftp-server \
        openssh-sshd \
        packagegroup-core-boot \
        packagegroup-petalinux-lmsensors \
        parted \
        pmic-prog \
        run-postinsts \
        tcf-agent \
        udev-extraconf \
        bluez5 \
        connman \
        git \
        iw \
        libftdi \
        packagegroup-base-extended \
        packagegroup-petalinux \
        packagegroup-petalinux-benchmarks \
        packagegroup-petalinux-utils \
        wilc3000-fw \
        wilc \
"
