FROM ubuntu:focal-20220801 as xil

ARG XIL_VERSION=2022.2
ARG XIL_INSTALLER=Xilinx_Unified_${XIL_VERSION}_1014_8888
ARG XIL_INSTALLER_MD5= 4b4e84306eb631fe67d3efb469122671
ARG XIL_INSTALLER_TAR=${XIL_INSTALLER}.tar.gz

ARG BOARD=ultra96v2
ARG UID=1000
ARG GID=1000

WORKDIR /build

RUN yes | unminimize \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    # Vivado/Vitis dependencies
    sudo \
    xorg \
    curl \
    libtinfo5 \
    locales \
    software-properties-common \
    python3 \
    python3-dev \
    python3-pip \
    xz-utils \
    libcanberra-gtk-module \
    libswt-gtk-4-jni \
    gnupg \
    pigz \
    # Petalinux dependencies
    iproute2 \
    gawk \
    python \
    build-essential \
    git \
    net-tools \
    libncurses5-dev \
    update-inetd \
    tftpd \
    zlib1g-dev \
    libssl-dev \
    flex \
    bison \
    wget \
    diffstat \
    chrpath \
    socat \
    xterm \
    autoconf \
    libtool \
    tar \
    unzip \
    texinfo \
    gcc-multilib \
    automake \
    zlib1g:i386 \
    screen \
    pax \
    gzip \
    cpio \
    python3-pexpect \
    debianutils \
    iputils-ping \
    python3-git \
    python3-jinja2 \
    libegl1-mesa \
    libsdl1.2-dev \
    pylint3 \
    less \
    bc \
    rsync \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen "en_US.UTF-8" && update-locale LANG="en_US.UTF-8"

RUN addgroup --gid ${GID} xil \
    && adduser --gecos "" --uid ${UID} --gid ${GID} --shell=/bin/bash xil \
    && mkdir /xilinx \
    && chown xil:xil /build /xilinx \
    && echo 'xil ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Petalinux expects sh to be bash
RUN cd /bin && ln -sf bash sh

USER xil

ENV XIL_VIVADO=/xilinx/Vivado/${XIL_VERSION}
ENV XIL_PETALINUX=/xilinx/PetaLinux/${XIL_VERSION}

COPY --chown=xil:xil petalinux_config.txt .
COPY --chown=xil:xil vitis_config.txt .

# Install petalinux and vitis
# Uses a local webserver to download installer archiver to avoid saving installer in seperate layer
# Using a COPY for the xilinx installer would add 90GiB to the final image
RUN curl http://localhost:8080/${XIL_INSTALLER_TAR} > ${XIL_INSTALLER_TAR} \
    && md5sum ${XIL_INSTALLER_TAR} | grep ${XIL_INSTALLER_MD5} \
    && tar -I pigz -xvf ${XIL_INSTALLER_TAR} \
    && rm -rf ${XIL_INSTALLER_TAR} \
    && ${XIL_INSTALLER}/xsetup --batch Install \
    --agree XilinxEULA,3rdPartyEULA \
    --config ./petalinux_config.txt \
    && ${XIL_INSTALLER}/xsetup --batch Install \
    --agree XilinxEULA,3rdPartyEULA \
    --config ./vitis_config.txt \
    && rm -rf ./xil-install ./*.txt ./${XIL_INSTALLER} \
    # Large files only needed for versal
    # https://support.xilinx.com/s/question/0D52E00006ln0TnSAI/question-regarding-vivado-20211-installation-size-and-device-support?language=en_US
    ${XIL_VIVADO}/data/parts/xilinx/devint/vault/versal \
    # Petalinux installer copy
    ${XIL_PETALINUX}/bin

# Development tool dependencies
RUN curl -sS https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg \
    && sudo mv bazel.gpg /etc/apt/trusted.gpg.d/ \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" \
    | sudo tee /etc/apt/sources.list.d/bazel.list && sudo apt-get update \
    && sudo apt-get update \
    && DEBIAN_FRONTEND='noninteractive' sudo apt-get install --no-install-recommends -y \
    gtkwave \
    libudev-dev \
    pkg-config \
    # Verilator build requirements
    perl \
    perl-doc \
    libfl-dev \
    zlibc zlib1g \
    ccache \
    libgoogle-perftools-dev \
    numactl \
    # Verible build requirements
    apt-transport-https \
    openjdk-11-jdk \
    zip \
    bazel \
    device-tree-compiler \
    && sudo rm -rf /var/lib/apt/lists/*

# Install verilator
RUN git clone https://github.com/verilator/verilator \
    && cd verilator \
    && git checkout v5.002 \
    && autoconf \
    && ./configure --prefix=/opt/verilator \
    && make -j $(nproc) \
    && make test \
    && sudo make install \
    && cd /build \
    && rm -rf verilator

ENV PATH="$PATH:/opt/verilator/bin"

# Install verible
RUN git clone https://github.com/chipsalliance/verible.git \
    && cd verible \
    && git checkout v0.0-2492-gd122fac8 \
    && sudo mkdir -p /opt/verible/bin \
    && bazel run -c opt :install -- -s /opt/verible/bin \
    && cd /build \
    && rm -rf verible

ENV PATH="$PATH:/opt/verible/bin"

# Install Avnet board definition files
RUN git clone https://github.com/Avnet/bdf.git \
    && cd bdf \
    && git checkout 07b475ef7ae44e094c9aa70a1c568339d4350a3c \
    && cp -r ${BOARD} /xilinx/Vivado/${XIL_VERSION}/data/boards/board_files \
    && cd /build \
    && rm -rf bdf

# Install UVM
RUN curl https://www.accellera.org/images/downloads/standards/uvm/UVM-18002-2020-11tar.gz > uvm.tar.gz \
    && md5sum uvm.tar.gz | grep 90191a7623416ba24176c88a9032d0db \
    && tar -xf uvm.tar.gz \
    && sudo mv 1800.2-2020-1.1 /opt/uvm \
    && sudo chown -R root:root /opt/uvm \
    && rm -rf uvm.tar.gz

WORKDIR /app

RUN sudo rm -rf /build

# Environment variables that get rid of xilinx tools warning/error messages
ENV TERMINFO=/lib/terminfo
ENV NO_AT_BRIDGE=1

# Automatically source xilinx tools
RUN echo ". ${XIL_VIVADO}/settings64.sh" >> /home/xil/.bashrc \
    && echo ". ${XIL_PETALINUX}/tool/settings.sh" >> /home/xil/.bashrc
