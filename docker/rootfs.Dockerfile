FROM ubuntu:noble-20241118.1 as rootfs

RUN apt-get update

RUN DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    ubuntu-minimal \
    dbus \
    systemd-resolved \
    systemd-timesyncd \
    fpga-manager-xlnx \
    openssh-server \
    vim \
    htop

RUN adduser --disabled-password --gecos "" --shell=/bin/bash zynqmp \
    && echo "zynqmp:zynqmp" | chpasswd \
    && usermod -a -G dialout,adm,sudo zynqmp
