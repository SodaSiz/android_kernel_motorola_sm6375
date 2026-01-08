# AnyKernel3 Ramdisk Mod Script
OS=${1:-"auto"};
target_lp=${2:-"auto"};

## AnyKernel setup
# global properties
properties() { '
kernel.string=Kernel GKI LineageOS pour Motorola G84 5G (bangkk)
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=1
device.name1=bangkk
device.name2=Motorola G84 5G
device.name3=moto g84 5G
supported.versions=11, 12, 13, 14
supported.patchlevels=
'; }

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables
import_files "anykernel.sh";

## AnyKernel boot install
split_boot;

# Si tu as des fichiers DTB générés (souvent requis sur G84)
if [ -f $home/dtb ]; then
  write_boot;
else
  # Pour GKI standard
  flash_boot;
fi

## AnyKernel vendor_dlkm install (Installation des modules)
# Sur les kernels 5.4+ GKI, les modules vont souvent dans vendor_dlkm
split_vendor_dlkm;
install_sh "/vendor/lib/modules";
# On injecte les .ko qui ont été copiés dans le dossier modules/ du zip
mount -o rw,remount /vendor;
cp -fp $home/modules/vendor/lib/modules/*.ko /vendor/lib/modules/;
