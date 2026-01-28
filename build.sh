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

export PATH="$CLANG_DIR/bin:$PATH"

# ==============================
# Arch
# ==============================
export ARCH=arm64
export SUBARCH=arm64

# ==============================
# Host tools (IMPORTANT)
# ==============================
export HOSTCC=gcc
export HOSTCXX=g++
export HOSTLD=ld

# ==============================
# LLVM
# ==============================
export LLVM=1
export LLVM_IAS=1

# ==============================
# Device
# ==============================
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
# Make args
# ==============================
MAKE_ARGS="
CC=clang
AR=llvm-ar
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
OBJSIZE=llvm-size
STRIP=llvm-strip
LD=ld.lld
LLVM=1
LLVM_IAS=1
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=aarch64-linux-gnu-
KCFLAGS=-Wno-error
"
# ==============================
# Base defconfig
# ==============================
make O=out ${MAKE_ARGS} gki_defconfig

# ==============================
# Merge vendor fragments (CRITIQUE)
# ==============================
scripts/kconfig/merge_config.sh -m \
    out/.config \
    arch/arm64/configs/vendor/holi_GKI.config \
    arch/arm64/configs/vendor/ext_config/lineage_moto-holi.config \
    arch/arm64/configs/vendor/ext_config/moto-holi-bangkk.config \
		arch/arm64/configs/vendor/ext_config/fix_vendor_symbols.config

# Temp Check for Audio and RMNET QMI
grep QMI out/.config
grep RMNET out/.config
grep SND_SOC_QCOM_APR out/.config


echo "🧹 Nettoyage de l'arbre source"
make mrproper


# ==============================
# Finalize config
# ==============================
make O=out ${MAKE_ARGS} olddefconfig

# ==============================
# Build kernel
# ==============================
make O=out ${MAKE_ARGS} -j$(nproc)

# ==============================
# Modules
# ==============================
make O=out ${MAKE_ARGS} \
    INSTALL_MOD_PATH=../modules \
    INSTALL_MOD_STRIP=1 \
    modules_install \
    -j$(nproc)

echo "Build terminé en $((SECONDS/60))m $((SECONDS%60))s"

