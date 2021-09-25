FROM ubuntu:18.04 as xil

ARG BOARD=ultra96v2
ARG XIL_INSTALLER=Xilinx_Unified_2021.2_1021_0703
ARG XIL_INSTALLER_MD5=c6f91186f332528a7b74a6a12a759fb6
ARG XIL_INSTALLER_TAR=${XIL_INSTALLER}.tar.gz

WORKDIR /build

# Vivado dependencies
RUN yes | unminimize && \
    apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    sudo xorg curl libtinfo5 locales software-properties-common \
    python3 python3-dev python3-pip xz-utils libcanberra-gtk-module gnupg && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen "en_US.UTF-8" && update-locale LANG="en_US.UTF-8"

RUN useradd -ms /bin/bash xil && \
    mkdir /xilinx && \
    chown xil:xil /build /xilinx && \
    echo 'xil ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER xil

ARG XIL_VERSION=2021.2
ENV XILINX_VIVADO=/xilinx/Vivado/${XIL_VERSION}

# Copy xilinx installation files
COPY --chown=xil:xil install_config.txt .

# Install vivado and vitis
RUN curl -f http://localhost:8080/${XIL_INSTALLER_TAR} > ${XIL_INSTALLER_TAR} && \
    md5sum ${XIL_INSTALLER_TAR} | grep ${XIL_INSTALLER_MD5} && \
    tar -xvf ${XIL_INSTALLER_TAR} && \
    rm -rf ${XIL_INSTALLER_TAR} && \
    ${XIL_INSTALLER}/xsetup --batch Install \
    --agree XilinxEULA,3rdPartyEULA \
    --config ./install_config.txt && \
    rm -rf ./xil-install ./install_config.txt ./${XIL_INSTALLER} \
    ${XILINX_VIVADO}/data/parts/xilinx/devint/vault/versal

# Development dependencies
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg && \
    sudo mv bazel.gpg /etc/apt/trusted.gpg.d/ && \
    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | \
    sudo tee /etc/apt/sources.list.d/bazel.list && sudo apt-get update && \
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test && sudo apt-get update && \
    DEBIAN_FRONTEND='noninteractive' sudo apt-get install --no-install-recommends -y \
    git parted tar gtkwave libudev-dev build-essential gcc-11 g++-11 pkg-config automake \
    # Verilator build requirements
    perl perl-doc python3 make libfl-dev zlibc zlib1g zlib1g-dev \
    ccache libgoogle-perftools-dev numactl autoconf flex bison \
    # Verible build requirements
    apt-transport-https curl openjdk-11-jdk zip unzip bazel && \
    sudo ln -f -s /usr/bin/gcc-11 /usr/bin/gcc && \
    sudo ln -f -s /usr/bin/g++-11 /usr/bin/g++ && \
    sudo rm -rf /var/lib/apt/lists/*

# Install verilator
ARG verilator_install_url=https://github.com/verilator/verilator
ARG verilator_install_rev=stable

RUN git clone ${verilator_install_url} && cd verilator git checkout ${verilator_install_rev} && \
    autoconf && ./configure --prefix=/usr/local && make -j $(nproc) && sudo make install && \
    cd .. && rm -rf verilator

ARG verible_install_url=https://github.com/chipsalliance/verible.git

# Install verible
RUN git clone ${verible_install_url} \
    && cd verible \
    && bazel run -c opt :install -- -s /usr/local/bin

ARG bdf_install_url=https://github.com/Avnet/bdf.git

# Install board definition files
RUN git clone ${bdf_install_url} \
    && cd bdf \
    && cp -r ${BOARD} /xilinx/Vivado/${XIL_VERSION}/data/boards/board_files \
    && cd .. \
    && rm -rf bdf

WORKDIR /app

# Environment variables that get rid of xilinx tools warning/error messages
ENV TERMINFO=/lib/terminfo
ENV NO_AT_BRIDGE=1

# Automatically source xilinx tools
RUN echo ". $XILINX_VIVADO/settings64.sh" >> /home/xil/.bashrc
