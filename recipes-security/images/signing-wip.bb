DESCRIPTION = "Image building and preparation for signing and repackaging post processing"
LICENSE = "MIT"

inherit core-image
# Secure artifacts nicely prepares and separates relevant artifact builds for a postprocessing (Yocto external)
# The post processing step could just get the respective files, but it does make it easier to keep track like this, per build (albeit a bit wasteful)
inherit secure-artifacts

# This is what core-image-minimal does, and adds some room for systemd. I might do that too
IMAGE_INSTALL = "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL}"
IMAGE_INSTALL += "e2fsprogs-ptest parted"
IMAGE_INSTALL += "pciutils usbutils vim-tiny"

IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "", d)}"

#
# Yocto defaults to 1024 bytes block sizes (to keep things minimal). dmverity must either be created with this block size, or alternatively, increase
# the default size (which would yield better performance in most devices this way or another)
# To do this for verity, you need something like (for the data block, not neessarily for the hash)
# veritysetup format \
#    --data-block-size=1024 \
#    --hash-block-size=1024 \
#    --format=1 \
#   
EXTRA_IMAGECMD:ext4 = "-b 4096"
