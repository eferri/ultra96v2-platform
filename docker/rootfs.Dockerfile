FROM ubuntu:noble-20240605 as rootfs

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

RUN DEBIAN_FRONTEND='noninteractive' apt-get upgrade -y

RUN adduser --disabled-password --gecos "" --shell=/bin/bash zynqmp \
    && echo "zynqmp:zynqmp" | chpasswd \
    && usermod -a -G dialout,adm,sudo zynqmp

COPY ./netplan.yml /etc/netplan/99_config.yaml

RUN rm -rf /boot \
    && chmod 600 /etc/netplan/99_config.yaml
