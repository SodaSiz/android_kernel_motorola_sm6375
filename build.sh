#!/bin/bash
set -e

SECONDS=0
export KBUILD_BUILD_USER="SodaSiz"
export ROOT_DIR=$(pwd)

# ==============================
# Toolchain
# ==============================
CLANG_DIR="$ROOT_DIR/toolchain/proton-clang"

if [ ! -x "$CLANG_DIR/bin/clang" ]; then
    echo "ERROR: Proton Clang introuvable"
    exit 1
fi

# ⚠️ PATH PROPRE : système d’abord, clang ensuite
export PATH=/usr/bin:/bin:$CLANG_DIR/bin

# ==============================
# Arch
# ==============================
export ARCH=arm64
export SUBARCH=arm64

# ==============================
# HOST TOOLS (CRITIQUE)
# ==============================
export HOSTCC=/usr/bin/gcc
export HOSTCXX=/usr/bin/g++
export HOSTLD=/usr/bin/ld
export HOSTAR=/usr/bin/ar
export HOSTSTRIP=/usr/bin/strip

# ==============================
# Kernel toolchain (LLVM only)
# ==============================
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export OBJSIZE=llvm-size
export STRIP=llvm-strip

export LLVM=1
export LLVM_IAS=1
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-

# ==============================
# AnyKernel
# ==============================
export AnyKernel3_DIR="$ROOT_DIR/AnyKernel3"
export TIME="$(date +%Y%m%d)"
export modpath="$AnyKernel3_DIR/modules/vendor/lib/modules"
[ -z "$DEVICE" ] && export DEVICE="g84_gdx"

# ==============================
# Clean / Dirty
# ==============================
if [[ -z "$1" || "$1" == "-c" ]]; then
    rm -rf out modules
elif [[ "$1" != "-d" ]]; then
    echo "Usage: -c (clean) | -d (dirty)"
    exit 1
fi

# ==============================
# Make args (SAFE)
# ==============================
MAKE_ARGS="
O=out
ARCH=arm64
LLVM=1
LLVM_IAS=1
KCFLAGS=-Wno-error
"

# ==============================
# Config
# ==============================
make $MAKE_ARGS \
    gki_defconfig \
    vendor/holi_GKI.config \
    vendor/ext_config/lineageos_moto-holi.config \
    vendor/ext_config/moto-holi-bangkk.config

# ==============================
# Kernel build
# ==============================
make $MAKE_ARGS -j$(nproc)

# ==============================
# Modules
# ==============================
make $MAKE_ARGS \
    INSTALL_MOD_PATH=../modules \
    INSTALL_MOD_STRIP=1 \
    modules_install \
    -j$(nproc)

# ==============================
# Packaging
# ==============================
rm -rf "$modpath"
mkdir -p "$modpath"

cp out/arch/arm64/boot/Image "$AnyKernel3_DIR/Image"
[ -f out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb "$AnyKernel3_DIR/dtb"
[ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img "$AnyKernel3_DIR/dtbo.img"

find modules/lib/modules -name '*.ko' -exec cp {} "$modpath/" \;

MO

