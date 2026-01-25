#!/bin/bash
set -e

SECONDS=0
export KBUILD_BUILD_USER="SodaSiz"
export ROOT_DIR=$(pwd)

CLANG_DIR="$ROOT_DIR/toolchain/proton-clang"
if [ ! -x "$CLANG_DIR/bin/clang" ]; then
  echo "ERROR: Proton Clang introuvable"
  exit 1
fi

# PATH
export PATH="$CLANG_DIR/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1

export AnyKernel3_DIR="$ROOT_DIR/AnyKernel3"
export TIME=$(date '+%Y%m%d')
export modpath="$AnyKernel3_DIR/modules/vendor/lib/modules"
[ -z "$DEVICE" ] && export DEVICE="g84_gdx"

# Build mode
if [[ -z "$1" || "$1" == "-c" ]]; then
  rm -rf out modules
fi

# Make arguments
ARGS="
CC=clang
AR=llvm-ar
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
STRIP=llvm-strip
READELF=llvm-readelf
OBJSIZE=llvm-size
LLVM=1
LLVM_IAS=1
CLANG_TRIPLE=aarch64-linux-gnu-
KCFLAGS=-Wno-error
CROSS_COMPILE=aarch64-linux-gnu-
"

# Kernel config
make O=out ${ARGS} \
  gki_defconfig \
  vendor/holi_GKI.config \
  vendor/ext_config/lineageos_moto-holi.config \
  vendor/ext_config/moto-holi-bangkk.config

# Kernel build (host tools use default linker)
make O=out ${ARGS} -j$(nproc --all)

# Modules
make O=out ${ARGS} -j$(nproc --all) INSTALL_MOD_PATH=../modules INSTALL_MOD_STRIP=1 modules_install

# Packaging AnyKernel3
rm -rf "$modpath"
mkdir -p "$modpath"
cp out/arch/arm64/boot/Image "$AnyKernel3_DIR/Image"
[ -f out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb "$AnyKernel3_DIR/dtb"
[ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img "$AnyKernel3_DIR/dtbo.img"
find modules/lib/modules -name '*.ko' -exec cp {} "$modpath/" \;

MOD_INTERNAL_DIR=$(ls -d modules/lib/modules/5.4* 2>/dev/null | head -n 1)
if [ -d "$MOD_INTERNAL_DIR" ]; then
  cp "$MOD_INTERNAL_DIR"/modules.{alias,dep,softdep} "$modpath"/
  sed 's|.*/||; s/\.ko$//' "$MOD_INTERNAL_DIR/modules.order" > "$modpath/modules.load"
fi

cd "$AnyKernel3_DIR"
zip -r9 "O_KERNEL_${DEVICE}_${TIME}.zip" . -x .git README.md '*placeholder'
mv *.zip "$ROOT_DIR"
cd "$ROOT_DIR"

echo "✅ Build terminé en $((SECONDS/60))m $((SECONDS%60))s"

