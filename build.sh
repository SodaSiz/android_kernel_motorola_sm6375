#!/bin/bash
set -e

SECONDS=0
export KBUILD_BUILD_USER="SodaSiz"
export ROOT_DIR=$(pwd)

# On s'assure que le dossier de sortie existe
mkdir -p out

# ==============================
# Toolchain
# ==============================
CLANG_DIR="$ROOT_DIR/toolchain/proton-clang"

[ ! -x "$CLANG_DIR/bin/clang" ] && {
    echo "ERROR: Proton Clang introuvable"
    exit 1
}

export PATH="$CLANG_DIR/bin:$PATH"

# ==============================
# Arch & LLVM
# ==============================
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export LLVM_IAS=1

# ==============================
# Make args (Ajout de O=out ici pour être systématique)
# ==============================
MAKE_ARGS="
O=out
CC=clang
AR=llvm-ar
NM=llvm-nm
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
READELF=llvm-readelf
OBJSIZE=llvm-size
STRIP=llvm-strip
LD=ld.lld
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=aarch64-linux-gnu-
KCFLAGS=-Wno-error
"

# 1. Nettoyage de sécurité (pour éviter l'erreur source tree not clean)
make clean
make mrproper
rm -rf out && mkdir -p out

echo "Build des configs"

# 2. Base config (On dirige vers out/)
make ${MAKE_ARGS} gki_defconfig

# 3. Merge vendor fragments
# Note : On merge vers out/.config et non .config à la racine
KCONFIG_CONFIG=out/.config scripts/kconfig/merge_config.sh -m -O out/ \
    out/.config \
    arch/arm64/configs/vendor/holi_GKI.config \
    arch/arm64/configs/vendor/ext_config/lineage_moto-holi.config \
    arch/arm64/configs/vendor/ext_config/moto-holi-bangkk.config \
    arch/arm64/configs/vendor/ext_config/fix_vendor_symbols.config

# 4. Finalize config
make ${MAKE_ARGS} olddefconfig

echo "Build du kernel"

# 5. Build kernel
make ${MAKE_ARGS} -j$(nproc)

echo "Build des modules"

# 6. Modules
make ${MAKE_ARGS} \
    INSTALL_MOD_PATH=../modules \
    INSTALL_MOD_STRIP=1 \
    modules_install \
    -j$(nproc)

echo "✅ Build terminé en $((SECONDS/60))m $((SECONDS%60))s"

# ==============================
# Packaging AnyKernel3
# ==============================
echo "📦 Préparation du ZIP AnyKernel3..."

# Vérifier si le dossier AnyKernel3 existe, sinon le cloner
if [ ! -d "AnyKernel3" ]; then
    echo "Clonage de AnyKernel3..."
    git clone https://github.com/osm0sis/AnyKernel3.git --depth=1
fi

# Nettoyer les anciens fichiers dans AnyKernel3
rm -rf AnyKernel3/Image AnyKernel3/dtb AnyKernel3/dtbo.img AnyKernel3/modules/vendor/lib/modules/*.ko

# 1. Copier l'image du kernel
cp out/arch/arm64/boot/Image AnyKernel3/
cp out/.config AnyKernel3/config

# 2. Copier le DTB et DTBO (Indispensable pour Motorola Holi)
[ -f out/arch/arm64/boot/dtb ] && cp out/arch/arm64/boot/dtb AnyKernel3/
[ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img AnyKernel3/

# 3. Copier les modules .ko
mkdir -p AnyKernel3/modules/vendor/lib/modules
find modules/lib/modules/ -name "*.ko" -exec cp {} AnyKernel3/modules/vendor/lib/modules/ \;

cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} AnyKernel3/modules/vendor/lib/modules/
cp out/modules/lib/modules/5.4*/modules.order AnyKernel3/modules/vendor/lib/modules/modules.load

# 4. Créer le ZIP
DATE=$(date +"%Y%m%d-%H%M")
ZIP_NAME="Kernel-LineageOS-${DEVICE}-${DATE}.zip"

cd AnyKernel3
zip -r9 "../$ZIP_NAME" * -x .git* README.md *placeholder
cd ..

echo "✅ ZIP créé : $ZIP_NAME"
echo "✅ Build terminé en $((SECONDS/60))m $((SECONDS%60))s"
