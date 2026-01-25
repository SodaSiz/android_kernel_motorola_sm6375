#!/bin/bash

SECONDS=0
export KBUILD_BUILD_USER=SodaSiz
export ROOT_DIR=$(pwd)

# --- Détection de la Toolchain ---
CLANG_DIR=$(ls -d $ROOT_DIR/toolchain/proton-clang 2>/dev/null | head -n 1)

if [ -z "$CLANG_DIR" ]; then
    echo "ERROR: Proton Clang non trouvé dans toolchain/"
    exit 1
fi

export PATH="$CLANG_DIR/bin:$PATH"

# --- Variables Globales ---
export LLVM=1
export LLVM_IAS=1
export ARCH=arm64
export SUBARCH=arm64
export AnyKernel3_DIR=$ROOT_DIR/AnyKernel3
export TIME="$(date "+%Y%m%d")"
export modpath=${AnyKernel3_DIR}/modules/vendor/lib/modules

[ -z "$DEVICE" ] && export DEVICE=g84_gdx

# --- Nettoyage ---
if [[ -z "$1" || "$1" = "-c" ]]; then
    echo "------- Clean Build -------"
    rm -rf out modules
elif [ "$1" = "-d" ]; then
    echo "------- Dirty Build -------"
else
    echo "Erreur: Utilise -c (clean) ou -d (dirty)"
    exit 1
fi

# --- Arguments de compilation pour kernel uniquement ---
ARGS="
CC=clang \
AR=llvm-ar \
NM=llvm-nm \
AS=llvm-as \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
READELF=llvm-readelf \
OBJSIZE=llvm-size \
STRIP=llvm-strip \
LLVM_AR=llvm-ar \
LLVM_DIS=llvm-dis \
LLVM_NM=llvm-nm \
LLVM=1 \
LLVM_IAS=1 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
KCFLAGS=-Wno-error
"

echo "------- Génération de la Config -------"
make O=out ${ARGS} gki_defconfig \
     vendor/holi_GKI.config \
     vendor/ext_config/lineageos_moto-holi.config \
     vendor/ext_config/moto-holi-bangkk.config

echo "------- Compilation du Kernel -------"
# Passer LD uniquement ici, pour le kernel
make O=out ${ARGS} LD=$CLANG_DIR/bin/ld.lld -j$(nproc --all)

# Vérification du succès
if [ ! -e "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Compilation échouée !"
    exit 1
fi

echo "------- Compilation des Modules -------"
make O=out ${ARGS} LD=$CLANG_DIR/bin/ld.lld -j$(nproc --all) \
     INSTALL_MOD_PATH=../modules INSTALL_MOD_STRIP=1 modules_install

# --- Packaging AnyKernel3 ---
echo "------- Packaging AnyKernel3 -------"
rm -rf ${modpath}/*
mkdir -p ${modpath}

cp out/arch/arm64/boot/Image ${AnyKernel3_DIR}/Image
[ -e out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb ${AnyKernel3_DIR}/dtb
[ -e out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img ${AnyKernel3_DIR}/dtbo.img

find modules/lib/modules/ -name '*.ko' -exec cp {} ${modpath}/ \;

if [ -d "modules/lib/modules" ]; then
    MOD_INTERNAL_DIR=$(ls -d modules/lib/modules/5.4*)
    cp ${MOD_INTERNAL_DIR}/modules.{alias,dep,softdep} ${modpath}/
    cat ${MOD_INTERNAL_DIR}/modules.order | sed 's/.*\///' | sed 's/\.ko$//' > ${modpath}/modules.load
fi

cd ${AnyKernel3_DIR}
ZIP_NAME="O_KERNEL_${DEVICE}_${TIME}.zip"
zip -r9 "$ZIP_NAME" * -x .git README.md *placeholder
mv "$ZIP_NAME" ..

echo -e "\n✅ Compilation terminée en $((SECONDS / 60))m $((SECONDS % 60))s"
cd ..

