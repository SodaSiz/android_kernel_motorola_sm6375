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
# Make args
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

# 1. Nettoyage de sécurité
make clean
make mrproper
rm -rf out && mkdir -p out

echo "Build des configs"

# 2. Base config : On commence par la base GKI standard
make ${MAKE_ARGS} gki_defconfig

# 3. Utilisation de ton fichier moto.config (Ancien config.gz)
# On commente les anciens merges spécifiques au vendor "holi"
# KCONFIG_CONFIG=out/.config scripts/kconfig/merge_config.sh -m -O out/ \
#     out/.config \
#     arch/arm64/configs/vendor/holi_GKI.config \
#     arch/arm64/configs/vendor/ext_config/lineage_moto-holi.config \
#     arch/arm64/configs/vendor/ext_config/moto-holi-bangkk.config \
#     arch/arm64/configs/vendor/ext_config/fix_vendor_symbols.config

echo "Fusion du fichier moto.config personnalisé..."
KCONFIG_CONFIG=out/.config scripts/kconfig/merge_config.sh -m -O out/ \
    out/.config \
    arch/arm64/configs/vendor/moto.config

# 4. Finalize config (vérifie les dépendances et met à jour le .config)
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
