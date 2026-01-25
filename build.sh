#!/bin/bash

# --- Configuration de KernelSU-Next ---
# Si tu souhaites l'activer, décommente les lignes ci-dessous
# [ ! -d "KernelSU-Next" ] && git submodule add https://github.com/tiann/KernelSU-Next
# [ -e "KernelSU-Next/kernel/setup.sh" ] && source KernelSU-Next/kernel/setup.sh

SECONDS=0
export KBUILD_BUILD_USER=SodaSiz
export ROOT_DIR=$(pwd)

# --- Détection de la Toolchain (Dynamique) ---
# On cherche le dossier clang qui commence par "clang-r" dans toolchain
CLANG_DIR=$(ls -d $ROOT_DIR/toolchain/clang/clang-r* 2>/dev/null | head -n 1)
GCC64_DIR=$ROOT_DIR/toolchain/gcc64
GCC32_DIR=$ROOT_DIR/toolchain/gcc32

# Vérification de sécurité
if [ -z "$CLANG_DIR" ] || [ ! -d "$GCC64_DIR" ]; then
    echo "ERROR: Toolchain non trouvée dans $ROOT_DIR/toolchain/"
    echo "Vérifie tes étapes de téléchargement dans le YAML."
    exit 1
fi

# Mise à jour du PATH (Priorité à Clang AOSP)
export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"

# Force l'export du linker pour Kconfig (Fix 'ld.lld not found' error)
export LD=ld.lld

# Vérification du bon fonctionnement du PATH
if ! command -v ld.lld &> /dev/null; then
    echo "ERROR: ld.lld est introuvable dans le PATH !"
    exit 1
fi

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

# --- Arguments de compilation ---
# Note: On utilise les noms de binaires car ils sont dans le PATH
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
CLANG_TRIPLE=aarch64-linux-gnu- \
KCFLAGS=-Wno-error \
"

echo "------- Génération de la Config -------"
# Fusion des fichiers de config (GKI + Motorola + Bangkk)
make O=out ${ARGS} gki_defconfig vendor/holi_GKI.config vendor/ext_config/lineageos_moto-holi.config vendor/ext_config/moto-holi-bangkk.config

echo "------- Compilation du Kernel -------"
make O=out ${ARGS} -j$(nproc --all)

# Vérification du succès
if [ ! -e "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Compilation échouée ! Fichier Image absent."
    exit 1
fi

echo "------- Compilation des Modules -------"
# On installe les modules dans un dossier temporaire 'modules'
make O=out ${ARGS} -j$(nproc --all) INSTALL_MOD_PATH=../modules INSTALL_MOD_STRIP=1 modules_install

# --- Packaging AnyKernel3 ---
echo "------- Packaging AnyKernel3 -------"
rm -rf ${modpath}/*
mkdir -p ${modpath}

# Copie du Noyau et des DTB/DTBO
cp out/arch/arm64/boot/Image ${AnyKernel3_DIR}/Image
[ -e out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb ${AnyKernel3_DIR}/dtb
[ -e out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img ${AnyKernel3_DIR}/dtbo.img

# Extraction et copie des modules (.ko)
find modules/lib/modules/ -name '*.ko' -exec cp {} ${modpath}/ \;

# Génération des fichiers de chargement des modules
if [ -d "modules/lib/modules" ]; then
    MOD_INTERNAL_DIR=$(ls -d modules/lib/modules/5.4*)
    cp ${MOD_INTERNAL_DIR}/modules.{alias,dep,softdep} ${modpath}/
    # Création du modules.load simplifié pour Android
    cat ${MOD_INTERNAL_DIR}/modules.order | sed 's/.*\///' | sed 's/\.ko$//' > ${modpath}/modules.load
fi

# Création du ZIP final
cd ${AnyKernel3_DIR}
ZIP_NAME="O_KERNEL_${DEVICE}_${TIME}.zip"
zip -r9 "$ZIP_NAME" * -x .git README.md *placeholder
mv "$ZIP_NAME" ..

echo -e "\n✅ Compilation terminée avec succès en $((SECONDS / 60))m $((SECONDS % 60))s"
cd ..
