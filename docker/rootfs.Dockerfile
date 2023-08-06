FROM ubuntu:lunar-20230816 as rootfs

RUN yes | unminimize

RUN apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get upgrade \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y ubuntu-minimal \
    apt \
    dbus \
    netbase \
    sudo \
    systemd-resolved \
    systemd-timesyncd \
    udev \
    fpga-manager-xlnx \
    usbutils \
    lshw

RUN DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    openssh-server \
    vim \
    htop \
    git \
    pigz \
    less

RUN adduser --disabled-password --gecos "" --shell=/bin/bash zynqmp \
    && echo "zynqmp:zynqmp" | chpasswd \
    && usermod -a -G dialout,adm,sudo zynqmp

COPY ./netplan.yml /etc/netplan/99_config.yaml

RUN rm -rf /boot \
    && chmod 600 /etc/netplan/99_config.yaml
