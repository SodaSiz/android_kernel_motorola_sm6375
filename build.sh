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
# HOST TOOLS (CRITIQUE)
# ==============================
export HOSTCC=gcc
export HOSTCXX=g++
export HOSTLD=ld

# ==============================
# Kernel toolchain
# ==============================
export LLVM=1
export LLVM_IAS=1

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
# Make arguments
# ==============================
ARGS="
CC=clang
HOSTCC=gcc
HOSTCXX=g++
HOSTLD=ld
AR=llvm-ar
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
OBJSIZE=llvm-size
STRIP=llvm-strip
LLVM=1
LLVM_IAS=1
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=aarch64-linux-gnu-
KCFLAGS=-Wno-error
"

# ==============================
# Config
# ==============================
make O=out ${ARGS} \
    gki_defconfig \
    vendor/holi_GKI.config \
    vendor/ext_config/lineageos_moto-holi.config \
    vendor/ext_config/moto-holi-bangkk.config

# ==============================
# Kernel build
# ==============================
make O=out ${ARGS} \
    LD=ld.lld \
    -j$(nproc)

# ==============================
# Modules
# ==============================
make O=out ${ARGS} \
    LD=ld.lld \
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

MODDIR=$(ls -d modules/lib/modules/5.4* | head -n 1)
cp "$MODDIR"/modules.{alias,dep,softdep} "$modpath"/
sed 's|.*/||; s/\.ko$//' "$MODDIR/modules.order" > "$modpath/modules.load"

cd "$AnyKernel3_DIR"
ZIP="O_KERNEL_${DEVICE}_${TIME}.zip"
zip -r9 "$ZIP" . -x .git README.md '*placeholder'
mv "$ZIP" "$ROOT_DIR"
cd "$ROOT_DIR"

echo "✅ Build terminé en $((SECONDS/60))m $((SECONDS%60))s"

