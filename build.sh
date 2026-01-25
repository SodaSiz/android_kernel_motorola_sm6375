#!/bin/bash

# Init submodules pour KernelSU-Next
# [ ! -e "KernelSU-Next/kernel/setup.sh" ] && git submodule init && git submodule update

SECONDS=0
export KBUILD_BUILD_USER=SodaSiz

# Chemins vers les Toolchains (On utilise les variables définies par le script ou le PATH)
CLANG_DIR=$(pwd)/toolchain/clang/clang-r416155b
GCC64_DIR=$(pwd)/toolchain/gcc64
GCC32_DIR=$(pwd)/toolchain/gcc32

# Mise à jour du PATH pour être sûr
export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"

export LLVM=1
export LLVM_IAS=1
export AnyKernel3=AnyKernel3
export TIME="$(date "+%Y%m%d")"
export modpath=${AnyKernel3}/modules/vendor/lib/modules
export ARCH=arm64
export SUBARCH=arm64

if [ -z "$DEVICE" ]; then
    export DEVICE=g84_gdx
fi

# Gestion du nettoyage
if [[ -z "$1" || "$1" = "-c" ]]; then
    echo "Clean Build"
    rm -rf out
elif [ "$1" = "-d" ]; then
    echo "Dirty Build"
else
    echo "Error: Set $1 to -c or -d"
    exit 1
fi

# Définition propre des arguments de compilation
# On utilise directement les noms des binaires car ils sont dans le PATH
ARGS="
CC=clang \
LD=ld.lld \
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
CROSS_COMPILE=aarch64-linux-android- \
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
CLANG_TRIPLE=aarch64-linux-gnu-
"

echo "------- Config Génération -------"
# Note: On utilise 'make' avec les arguments définis au-dessus
make O=out ${ARGS} gki_defconfig vendor/holi_GKI.config vendor/ext_config/lineageos_moto-holi.config vendor/ext_config/moto-holi-bangkk.config

echo "------- Compilation du Kernel -------"
make O=out ${ARGS} -j$(nproc --all)

# Vérification
if [ ! -e "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Kernel image not found! Compilation failed."
    exit 1
fi

echo "------- Compilation des Modules -------"
make O=out ${ARGS} -j$(nproc --all) INSTALL_MOD_PATH=../modules INSTALL_MOD_STRIP=1 modules_install

# --- Reste du script (Packaging AnyKernel3) ---
# Nettoyage AnyKernel
rm -rf ${modpath}/*
rm -f ${AnyKernel3}/{Image,dtb,dtbo.img}

mkdir -p ${modpath}

# Copie des fichiers générés
cp out/arch/arm64/boot/Image ${AnyKernel3}/Image
[ -e out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb ${AnyKernel3}/dtb
[ -e out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img ${AnyKernel3}/dtbo.img

# Installation des modules .ko dans AnyKernel3
find out/modules/lib/modules/ -name '*.ko' -exec cp {} ${modpath}/ \;

# Génération des fichiers de dépendances modules
cd out/modules/lib/modules/*-*-*
cp modules.{alias,dep,softdep} ../../../../${modpath}/
cat modules.order | sed 's/.*\///' | sed 's/\.ko$//' > ../../../../${modpath}/modules.load
cd ../../../../../

# Zip final
cd ${AnyKernel3}
zip -r9 O_KERNEL_${DEVICE}-${TIME}.zip * -x .git README.md
echo -e "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s"

#source build.sta/${DEVICE}_mdconf
#for useles_modules in "${modules_to_nuke[@]}"; do
#  grep -vE "$useles_modules" ${modpath}/modules.load > /tmp/templd && mv /tmp/templd ${modpath}/modules.load
#done

#Zip
cd ${AnyKernel3}
zip -r9 O_KERNEL.${kmod}_${DEVICE}${KSUSTAT}-${TIME}.zip * -x .git README.md *placeholder
echo -e "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s"
