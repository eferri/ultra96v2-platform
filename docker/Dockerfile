FROM ubuntu:jammy-20240627.1 as xil

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

# Build dependencies
RUN curl -sS https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/bazel.gpg \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" > /etc/apt/sources.list.d/bazel.list \
    && apt-add-repository ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    git \
    build-essential \
    pkg-config \
    gcc-13 \
    g++-13 \
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
    bazel-6.5.0 \
    # u-boot build requirements
    bc \
    libssl-dev \
    uuid-dev \
    libgnutls28-dev

USER xil

# Build, test and install verilator
RUN git clone https://github.com/verilator/verilator \
    && cd verilator \
    && git checkout v5.026 \
    && autoconf \
    && ./configure --prefix=/tools/verilator \
    && make -j$(nproc) \
    && make test -j$(nproc) \
    && make install \
    && cd ../ \
    && rm -rf ./verilator

# Build, test and install verible
RUN git clone https://github.com/chipsalliance/verible.git \
    && cd verible \
    && git checkout v0.0-3752-g8b64887e \
    && mkdir -p /tools/verible/bin \
    && bazel-6.5.0 run -c opt :install -- /tools/verible/bin \
    && bazel-6.5.0 test -c opt //... \
    && cd ../ \
    && rm -rf ./verible

USER root

# Install development tools
RUN curl -sS https://apt.llvm.org/llvm-snapshot.gpg.key > /etc/apt/trusted.gpg.d/apt.llvm.org.asc \
    && apt-add-repository deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    vim \
    universal-ctags \
    gtkwave \
    device-tree-compiler \
    libudev-dev \
    cmake \
    clang-18 \
    clang-tools-18 \
    clang-format-18 \
    clang-tidy-18 \
    clangd-18 \
    lldb-18 \
    gdb \
    u-boot-tools \
    less \
    libguestfs-tools \
    linux-image-kvm \
    ninja-build \
    qemu-system-arm \
    && chmod 0644 /boot/vmlinuz* \
    && update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-18 10 \
    && update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-18 10 \
    && update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-18 10 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 10 \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 10 \
    && update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-18 10 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 10 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 10

USER xil

WORKDIR /app

ENV XIL_VIVADO=/xilinx/Vivado/${XIL_VERSION}
ENV XIL_VITIS=/xilinx/Vitis/${XIL_VERSION}

ENV PATH="$PATH:/tools/verible/bin"
ENV PATH="$PATH:/tools/verilator/bin"

# Environment variables that get rid of xilinx tools warning/error messages
ENV TERMINFO=/lib/terminfo
ENV NO_AT_BRIDGE=1

# Cleanup
RUN rm -rf /build/*
