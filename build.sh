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

# 5. Build kernel
make ${MAKE_ARGS} -j$(nproc)

# 6. Modules
make ${MAKE_ARGS} \
    INSTALL_MOD_PATH=../modules \
    INSTALL_MOD_STRIP=1 \
    modules_install \
    -j$(nproc)

echo "✅ Build terminé en $((SECONDS/60))m $((SECONDS%60))s"
