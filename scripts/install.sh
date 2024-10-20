#! /usr/bin/env bash
set -e

export SEL4_PREFIX="${HOME}/.rust-sel4/"
export SEL4_INSTALL_DIR="${HOME}/.rust-sel4/"
INSTALL_MODE="rel4"

function show_usage() {
	    cat <<EOF
Usage: $0 [options] ...
OPTIONS:
    -h, --help              Display this help and exit.
    -a, --all               Install all env.
    -r, --rustsel4          Install rust sel4 runtime.
EOF
}

function install_apt() {
    sudo apt update
    sudo apt-get -y install build-essential cmake ccache ninja-build cmake-curses-gui \
        libxml2-utils ncurses-dev curl git doxygen device-tree-compiler u-boot-tools \
        python3-dev python3-pip python-is-python3 protobuf-compiler python3-protobuf \
        gcc-arm-linux-gnueabi g++-arm-linux-gnueabi gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
        gcc-riscv64-linux-gnu g++-riscv64-linux-gnu repo wget

    sudo apt-get install -y git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu \
        binutils-riscv64-linux-gnu curl autoconf automake autotools-dev curl libmpc-dev libmpfr-dev \
        libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev \
        libexpat-dev pkg-config libglib2.0-dev libpixman-1-dev libsdl2-dev libslirp-dev tmux python3 \
        python3-pip ninja-build
}

function install_pip() {
    pip install --user setuptools sel4-deps aenum pyelftools grpcio_tools
}
    
function install_qemu_and_toolchain() {
    mkdir -p ${HOME}/Downloads && cd ${HOME}/Downloads
    pushd ${HOME}/Downloads

    if [ ! -d qemu-8.2.5 ]; then
        wget https://download.qemu.org/qemu-8.2.5.tar.xz
        tar xvJf qemu-8.2.5.tar.xz
    fi

    pushd qemu-8.2.5
    # Install riscv64 qemu
    rm -rf build
    ./configure --target-list=riscv64-softmmu,riscv64-linux-user
    make -j$(nproc)
    sudo make install
    
    make clean
    rm -rf build
    # Install aarch64 qemu
    ./configure --target-list=aarch64-softmmu,aarch64-linux-user
    make -j$(nproc)
    sudo make install
    popd

    # Download riscv unknown toolchain
    if ! command -v riscv64-unknown-linux-gnu-gcc >/dev/null 2>&1
    then
        rm -rf riscv*
        wget https://github.com/yfblock/rel4-docker/releases/download/toolchain/riscv.tar.gz
        tar xzvf riscv.tar.gz
    fi
    popd
}

function install_rust() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y --no-modify-path \
        --default-toolchain nightly-2024-09-01 \
        --component rust-src cargo clippy rust-docs rust-src rust-std rustc rustfmt \
        --target aarch64-unknown-none-softfloat riscv64imac-unknown-none-elf
}

function install_sel4() {
        git clone https://github.com/seL4/seL4.git
        cd seL4
        git checkout cd6d3b8c25d49be2b100b0608cf0613483a6fffa
        cmake \
                -DCROSS_COMPILER_PREFIX=aarch64-linux-gnu- \
                -DCMAKE_INSTALL_PREFIX=$SEL4_INSTALL_DIR \
                -DKernelPlatform=qemu-arm-virt \
                -DKernelArmHypervisorSupport=ON \
                -DKernelVerificationBuild=OFF \
                -DARM_CPU=cortex-a57 \
                -G Ninja \
                -S . \
                -B build
        ninja -C build all
        ninja -C build install
        rm -rf seL4
}

function install_rustsel4() {
	local url="https://github.com/seL4/rust-sel4"
	local rev="1cd063a0f69b2d2045bfa224a36c9341619f0e9b"
        mkdir -p ${SEL4_INSTALL_DIR}
	local common_args="--git ${url} --rev ${rev} --root ${SEL4_INSTALL_DIR}"
        export CC_aarch64_unknown_none="aarch64-linux-gnu-gcc"
        cargo install ${common_args} sel4-kernel-loader-add-payload

        cargo install \
            -Z build-std=core,compiler_builtins \
            -Z build-std-features=compiler-builtins-mem \
            --target aarch64-unknown-none \
            $common_args \
            sel4-kernel-loader;
}

function install_rel4_runtime() {
    install_apt
    install_pip
    install_qemu_and_toolchain
    install_rust

    echo "export PATH=\${PATH}:${HOME}/.local/bin:${HOME}/Downloads/riscv/bin" >> ${HOME}/.bashrc
    echo "source \$HOME/.cargo/env" >> ${HOME}/.bashrc
}

function install_rust_sel4_runtime() {
    install_rust
    install_sel4
    install_rustsel4
    echo "export SEL4_PREFIX=\"\${HOME}/.rust-sel4/\"" >> ${HOME}/.bashrc
    echo "export SEL4_INSTALL_DIR=\"\${HOME}/.rust-sel4/\"" >> ${HOME}/.bashrc
    echo "export PATH=\${PATH}:\${HOME}/.rust-sel4/bin" >> ${HOME}/.bashrc
}

function install_all_runtime() {
    install_rel4_runtime
    install_rust_sel4_runtime
}

function parse_cmdline() {
    if [ "$#" -eq 0 ]; then
        install_rel4_runtime
        exit 0
    fi

    while [ $# -gt 0 ]; do
        local cmd="$1"
        shift
        case "${cmd}" in
            -a| --all)
                install_all_runtime
                exit 0
                ;;
            -r| --rustsel4)
                install_rust_sel4_runtime
                exit 0
                ;;                
            -h | --help)
                show_usage
                exit 0
                ;;
            -* | --*)
                show_usage
                exit 1
                ;;
        esac
    done
}

function main() {
    parse_cmdline "$@"
    echo "Don't forget to run source \${HOME}/.bashrc !!"
}

main "$@"
