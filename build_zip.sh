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
