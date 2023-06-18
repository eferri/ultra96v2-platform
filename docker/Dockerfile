FROM ubuntu:jammy-20230624 as xil

ARG XIL_VERSION
ARG XIL_INSTALLER
ARG XIL_INSTALLER_TAR
ARG XIL_INSTALLER_MD5

ARG UID
ARG GID
ARG KVM_GID

WORKDIR /build

RUN yes | unminimize \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    # Vivado dependencies
    xorg \
    curl \
    libtinfo5 \
    libncurses5 \
    locales \
    software-properties-common \
    python3 \
    python3-dev \
    python3-pip \
    xz-utils \
    gnupg \
    pigz \
    # Vitis Dependencies
    libcanberra-gtk-module \
    libswt-gtk-4-jni \
    libc6-dev-i386 \
    net-tools \
    graphviz \
    unzip \
    g++ \
    libncursesw5 \
    xvfb \
    file \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen "en_US.UTF-8" && update-locale LANG="en_US.UTF-8"

RUN addgroup --gid ${GID} xil \
    && adduser --disabled-password --gecos "" --uid ${UID} --gid ${GID} --shell=/bin/bash xil \
    && groupmod -g ${KVM_GID} kvm \
    && usermod -aG kvm xil \
    && mkdir /xilinx /tools \
    && chown xil:xil /build /xilinx /tools

USER xil

COPY --chown=xil:xil xilinx_config.txt .

# Install xilinx tools
# calculate md5sum and extract in parallel
RUN bash -c 'curl http://localhost:8080/${XIL_INSTALLER_TAR} | tee >(md5sum > ${XIL_INSTALLER_TAR}.md5) | tar -I pigz -xf -' \
    && if [ "${XIL_INSTALLER_MD5}" != "$(awk '{print $1}' ${XIL_INSTALLER_TAR}.md5)" ]; then echo "bad installer checksum" && exit 1; fi \
    && ./${XIL_INSTALLER}/xsetup --batch Install \
    --agree XilinxEULA,3rdPartyEULA \
    --config ./xilinx_config.txt \
    && rm -rf ./${XIL_INSTALLER} \
    # Large versal-specific files that can be removed
    # https://support.xilinx.com/s/question/0D52E00006ln0TnSAI/question-regarding-vivado-20211-installation-size-and-device-support?language=en_US
    && rm -rf /xilinx/SharedData/${XIL_VERSION}/data/parts/xilinx/devint/vault/versal

USER root

# Development tool dependencies
RUN curl -sS https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg \
    && mv bazel.gpg /etc/apt/trusted.gpg.d/ \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" \
    | tee /etc/apt/sources.list.d/bazel.list && apt-get update \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    git \
    vim \
    build-essential \
    universal-ctags \
    gtkwave \
    device-tree-compiler \
    libudev-dev \
    pkg-config \
    clang-tools-15 \
    gcc-12 \
    g++-12 \
    clang-15 \
    u-boot-tools \
    less \
    libguestfs-tools \
    linux-image-kvm \
    # Verilator build requirements
    help2man \
    perl \
    perl-doc \
    autoconf \
    flex \
    bison \
    ccache \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    mold \
    libgoogle-perftools-dev \
    numactl \
    # Verible build requirements
    apt-transport-https \
    zip \
    bazel \
    # qemu build requirements
    ninja-build \
    libglib2.0-dev \
    libgcrypt20-dev \
    zlib1g-dev \
    automake \
    libtool \
    libpixman-1-dev \
    libcapstone-dev \
    # u-boot build requirements
    bc \
    libssl-dev \
    uuid-dev \
    libgnutls28-dev \
    && chmod 0644 /boot/vmlinuz*

USER xil

# Install verilator
RUN git clone https://github.com/verilator/verilator \
    && cd verilator \
    && git checkout v5.012 \
    && autoconf \
    && ./configure --prefix=/tools/verilator \
    && make -j$(nproc) \
    && make test -j$(nproc) \
    && make install \
    && cd ../ \
    && rm -rf ./verilator

# Install verible
RUN git clone https://github.com/chipsalliance/verible.git \
    && cd verible \
    && git checkout v0.0-3401-g0b8cb4e0 \
    && mkdir -p /tools/verible/bin \
    && bazel run -c opt :install -- /tools/verible/bin \
    && bazel test -c opt //... \
    && cd ../ \
    && rm -rf ./verible

# Install qemu
RUN git clone https://github.com/Xilinx/qemu.git \
    && cd qemu \
    && git checkout xlnx_rel_v2023.1 \
    && mkdir build \
    && cd build \
    && ../configure --prefix=/tools/qemu --target-list="aarch64-softmmu,microblazeel-softmmu" \
    --enable-fdt --disable-kvm --disable-xen --enable-gcrypt \
    && make -j$(nproc) \
    && make install \
    && cd ../ \
    && rm -rf qemu

WORKDIR /app

ENV XIL_VIVADO=/xilinx/Vivado/${XIL_VERSION}
ENV XIL_VITIS=/xilinx/Vitis/${XIL_VERSION}

ENV PATH="$PATH:/tools/verible/bin"
ENV PATH="$PATH:/tools/verilator/bin"
ENV PATH="$PATH:/tools/qemu/bin"

# Environment variables that get rid of xilinx tools warning/error messages
ENV TERMINFO=/lib/terminfo
ENV NO_AT_BRIDGE=1

# Cleanup, automatically source xilinx tools
RUN rm -rf /build/* \
    && echo ". ${XIL_VITIS}/settings64.sh" >> /home/xil/.bashrc
