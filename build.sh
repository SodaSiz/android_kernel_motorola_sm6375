#!/bin/bash
set -e

# ==================================================
# Kernel build script — Proton Clang / Android 5.4
# ==================================================

SECONDS=0
export KBUILD_BUILD_USER=SodaSiz
export ROOT_DIR="$(pwd)"

# --------------------------------------------------
# Toolchain detection (Proton Clang)
# --------------------------------------------------
CLANG_DIR="$ROOT_DIR/toolchain/proton-clang"
GCC64_DIR="$ROOT_DIR/toolchain/gcc64"
GCC32_DIR="$ROOT_DIR/toolchain/gcc32"

if [ ! -x "$CLANG_DIR/bin/clang" ]; then
    echo "ERROR: Proton Clang introuvable dans $CLANG_DIR"
    exit 1
fi

if [ ! -d "$GCC64_DIR" ]; then
    echo "ERROR: GCC64 introuvable dans $GCC64_DIR"
    exit 1
fi

# --------------------------------------------------
# PATH & LLVM configuration
# --------------------------------------------------
export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"

export LLVM=1
export LLVM_IAS=1
export ARCH=arm64
export SUBARCH=arm64

# --------------------------------------------------
# Project paths
# --------------------------------------------------
export AnyKernel3_DIR="$ROOT_DIR/AnyKernel3"
export TIME="$(date '+%Y%m%d')"
export modpath="$AnyKernel3_DIR/modules/vendor/lib/modules"

[ -z "$DEVICE" ] && export DEVICE="g84_gdx"

# --------------------------------------------------
# Build mode
# --------------------------------------------------
if [[ -z "$1" || "$1" == "-c" ]]; then
    echo "======= Clean Build ======="
    rm -rf out modules
elif [[ "$1" == "-d" ]]; then
    echo "======= Dirty Build ======="
else
    echo "Usage: $0 [-c | -d]"
    exit 1
fi

# --------------------------------------------------
# Diagnostic (important en CI)
# --------------------------------------------------
echo "======= TOOLCHAIN INFO ======="
clang --version
ld.lld --version
aarch64-linux-android-gcc --version || true
arm-linux-androideabi-gcc --version || true
echo "=============================="

# --------------------------------------------------
# Make arguments
# --------------------------------------------------
ARGS="
CC=clang
LD=ld.lld
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
KCFLAGS=-Wno-error
"

# --------------------------------------------------
# Kernel config
# --------------------------------------------------
echo "======= Génération de la configuration ======="
make O=out ${ARGS} \
    gki_defconfig \
    vendor/holi_GKI.config \
    vendor/ext_config/lineageos_moto-holi.config \
    vendor/ext_config/moto-holi-bangkk.config

# --------------------------------------------------
# Kernel build
# --------------------------------------------------
echo "======= Compilation du kernel ======="
make O=out ${ARGS} -j"$(nproc --all)"

if [ ! -f "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Image du kernel absente"
    exit 1
fi

# --------------------------------------------------
# Modules
# --------------------------------------------------
echo "======= Compilation des modules ======="
make O=out ${ARGS} \
    -j"$(nproc --all)" \
    INSTALL_MOD_PATH="$ROOT_DIR/modules" \
    INSTALL_MOD_STRIP=1 \
    modules_install

# --------------------------------------------------
# AnyKernel3 packaging
# --------------------------------------------------
echo "======= Packaging AnyKernel3 ======="

rm -rf "$modpath"
mkdir -p "$modpath"

# Kernel + DT
cp out/arch/arm64/boot/Image "$AnyKernel3_DIR/Image"

[ -f out/arch/arm64/boot/dtb ] && \
    cp out/arch/arm64/boot/dtb "$AnyKernel3_DIR/dtb"

[ -f out/arch/arm64/boot/dtbo.img ] && \
    cp out/arch/arm64/boot/dtbo.img "$AnyKernel3_DIR/dtbo.img"

# Modules
find modules/lib/modules -name '*.ko' -exec cp {} "$modpath/" \;

MOD_INTERNAL_DIR=$(ls -d modules/lib/modules/5.4* 2>/dev/null | head -n 1)

if [ -d "$MOD_INTERNAL_DIR" ]; then
    cp "$MOD_INTERNAL_DIR"/modules.{alias,dep,softdep} "$modpath"/

    cat "$MOD_INTERNAL_DIR/modules.order" \
        | sed 's|.*/||' \
        | sed 's/\.ko$//' \
        > "$modpath/modules.load"
fi

# --------------------------------------------------
# Zip
# --------------------------------------------------
cd "$AnyKernel3_DIR"
ZIP_NAME="O_KERNEL_${DEVICE}_${TIME}.zip"

zip -r9 "$ZIP_NAME" . \
    -x .git README.md '*placeholder'

mv "$ZIP_NAME" "$ROOT_DIR"
cd "$ROOT_DIR"

echo
echo "✅ Build terminé avec succès en $((SECONDS / 60))m $((SECONDS % 60))s"
