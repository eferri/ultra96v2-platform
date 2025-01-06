FROM ubuntu:noble-20241118.1 AS xil

ARG XIL_VERSION
ARG XIL_INSTALLER
ARG XIL_INSTALLER_TAR
ARG XIL_INSTALLER_MD5

ARG UID
ARG GID
ARG KVM_GID

WORKDIR /build

# Install dependencies for Xilinx tools
# Install development tools later, to avoid repeating this step
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    # Vivado dependencies
    xorg \
    curl \
    libtinfo6 \
    libncurses6 \
    locales \
    software-properties-common \
    python3 \
    python3-dev \
    python3-pip \
    xz-utils \
    gnupg \
    unminimize \
    # Vitis Dependencies
    unzip \
    gcc \
    g++ \
    file \
    dbus-x11 \
    && yes | unminimize \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen "en_US.UTF-8" && update-locale LANG="en_US.UTF-8"

RUN groupmod --gid ${GID} --new-name xil ubuntu \
    && usermod --home /home/xil --move-home --gid ${GID} --login xil --shell=/bin/bash ubuntu \
    && groupmod -g ${KVM_GID} kvm \
    && usermod -aG kvm xil \
    && mkdir /xilinx /tools \
    && chown xil:xil /build /xilinx /tools

USER xil

COPY --chown=xil:xil xilinx_config.txt .

# Install xilinx tools
# calculate md5sum and extract in parallel
# md5sum --check re-calculates the checksum so check it against known value manually
RUN bash -c 'curl http://localhost:8080/${XIL_INSTALLER_TAR} | tee >(md5sum > ${XIL_INSTALLER_TAR}.md5) | tar -xf -' \
    && if [ "${XIL_INSTALLER_MD5}" != "$(awk '{print $1}' ${XIL_INSTALLER_TAR}.md5)" ]; then echo "bad installer checksum" && exit 1; fi \
    && ./${XIL_INSTALLER}/xsetup --batch Install \
    --agree XilinxEULA,3rdPartyEULA \
    --config ./xilinx_config.txt \
    && rm -rf ./* \
    # Large versal-specific files that can be removed
    # https://support.xilinx.com/s/question/0D52E00006ln0TnSAI/question-regarding-vivado-20211-installation-size-and-device-support?language=en_US
    && rm -rf /xilinx/SharedData/${XIL_VERSION}/data/parts/xilinx/devint/vault/versal

USER root

# Run vitis library install script
RUN /xilinx/Vitis/${XIL_VERSION}/scripts/installLibs.sh \
    && rm -rf /var/lib/apt/lists/*

# Build dependencies
RUN curl -sS https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/bazel.gpg \
    && echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" > /etc/apt/sources.list.d/bazel.list \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    git \
    build-essential \
    pkg-config \
    gcc-14 \
    g++-14 \
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
    bazel-8.0.0 \
    # u-boot build requirements
    bc \
    libssl-dev \
    uuid-dev \
    libgnutls28-dev \
    # gtkwave build requirements
    ninja-build \
    adwaita-icon-theme-full \
    cmake \
    gperf \
    desktop-file-utils \
    libgtk-3-dev \
    libgtk-4-dev \
    libbz2-dev \
    libjudy-dev \
    libgirepository1.0-dev \
    bzip2 \
    meson \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 10 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 10

USER xil

# Build, test and install verilator
RUN git clone https://github.com/verilator/verilator \
    && cd verilator \
    && git checkout v5.032 \
    && autoconf \
    && ./configure --prefix=/tools/verilator \
    && make -j$(nproc) \
    && make test -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf ./verilator

# Build, test and install verible
RUN git clone https://github.com/chipsalliance/verible.git \
    && cd verible \
    && git checkout v0.0-3894-g0a842c85 \
    && mkdir -p /tools/verible/bin \
    && bazel-8.0.0 build -c opt :install-binaries \
    && bazel-8.0.0 test -c opt //... \
    && .github/bin/simple-install.sh /tools/verible/bin \
    && cd .. \
    && rm -rf ./verible

# Build, install gtkwave
RUN git clone https://github.com/gtkwave/gtkwave.git \
    && cd gtkwave \
    && git checkout f668e5e \
    && mkdir -p /tools/gtkwave \
    && meson setup build --buildtype release --prefix /tools/gtkwave \
    && meson compile -C build \
    && meson test -C build \
    && meson install -C build \
    && cd .. \
    && rm -rf ./gtkwave

USER root

# Install development tools
RUN curl -sS https://apt.llvm.org/llvm-snapshot.gpg.key > /etc/apt/trusted.gpg.d/apt.llvm.org.asc \
    && echo "deb [arch=amd64] http://apt.llvm.org/noble/ llvm-toolchain-noble-19 main" > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && DEBIAN_FRONTEND='noninteractive' apt-get install --no-install-recommends -y \
    vim \
    universal-ctags \
    device-tree-compiler \
    libudev-dev \
    clang-19 \
    clang-tools-19 \
    clang-format-19 \
    clang-tidy-19 \
    clangd-19 \
    lldb-19 \
    gdb \
    u-boot-tools \
    less \
    pigz \
    libguestfs-tools \
    linux-image-kvm \
    qemu-utils \
    bash-completion \
    && rm -rf /var/lib/apt/lists/* \
    && chmod 0644 /boot/vmlinuz* \
    && update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-19 10 \
    && update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-19 10 \
    && update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-19 10 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 10 \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-19 10 \
    && update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-19 10

USER xil

WORKDIR /app

# Vivado preferences
COPY --chown=xil:xil --chmod=660 <<EOF /home/xil/.Xilinx/Vivado/${XIL_VERSION}/vivado.xml
<?xml version="1.0" encoding="UTF-8"?><preferences VERSION="10">
    <general>
        <CONFIRM_EXIT_APPLICATION value="false"/>
    </general>
</preferences>
EOF

# Cleanup
RUN rm -rf /build/*

# Source Xilinx tools
RUN echo "source /xilinx/Vitis/${XIL_VERSION}/settings64.sh" >> ~/.bashrc

# Environment variables that get rid of xilinx tools warning/error messages
ENV TERMINFO=/lib/terminfo
ENV NO_AT_BRIDGE=1

# Use environment variables
ENV XIL_VIVADO=/xilinx/Vivado/${XIL_VERSION}
ENV XIL_VITIS=/xilinx/Vitis/${XIL_VERSION}

ENV PATH="$PATH:/tools/verible/bin"
ENV PATH="$PATH:/tools/verilator/bin"
ENV PATH="$PATH:/tools/gtkwave/bin"

ENV TERM="xterm-256color"
