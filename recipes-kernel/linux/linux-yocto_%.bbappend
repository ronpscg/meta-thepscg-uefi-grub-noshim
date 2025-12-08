FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# DM_CRYPT
SRC_URI += "file://dmcrypt.scc file://dmcrypt.cfg \
"
# DM_VERITY
KERNEL_FEATURES:append = " features/device-mapper/dm-verity.scc"
# For DM_VERITY we can do the same, but we can also reuse the existing snippets (contents are below for reference)
#
# cd $TOPDIR/tmp/work/genericx86_64-poky-linux/linux-yocto/6.6.21+git/kernel-meta/features/device-mapper

# $ cat dm-verity.cfg 
# CONFIG_MD=y
# CONFIG_BLK_DEV_DM=y
# CONFIG_DM_VERITY=y
#
# $ cat dm-verity.scc 
# define KFEATURE_DESCRIPTION "Enable dm-verity (device-mapper block integrity checking target)"
#define KFEATURE_COMPATIBILITY all
# kconf non-hardware dm-verity.cfg

