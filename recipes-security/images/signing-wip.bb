DESCRIPTION = "Signing and secure-processing post build for core-image-minimal"
LICENSE = "MIT"

# Make this an image-type recipe
inherit core-image
inherit secure-artifacts

# We do NOT create our own rootfs — we piggyback on core-image-minimal
# This ensures our recipe does not try to build another filesystem.
# IMAGE_INSTALL += "e2fsprogs pciutils usbutils vim-tiny"
# IMAGE_INSTALL += "e2fsprogs"

# This is what core-image-minimal does, and adds some room for systemd. I might do that too
IMAGE_INSTALL = "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL}"
IMAGE_INSTALL += "e2fsprogs-ptest parted pciutils usbutils vim-tiny"
# Installs tons of crap
# So perhaps do this elsewhere, but for now let it build...
# DISTRO_FEATURES:remove = "wifi bluetooth alsa pcmcia"


# Force this image to depend on core-image-minimal
do_image[depends] += "core-image-minimal:do_image_complete"

# And the other thing would be putting IMAGE_INSTALL before inherit core-image 
IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "", d)}"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 90096", "", d)}"


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
#
EXTRA_IMAGECMD:ext4 = "-b 4096"
