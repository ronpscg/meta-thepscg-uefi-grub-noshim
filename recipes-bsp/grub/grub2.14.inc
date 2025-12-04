SUMMARY = "GRUB2 is the next-generation GRand Unified Bootloader"

DESCRIPTION = "GRUB2 is the next generaion of a GPLed bootloader \
intended to unify bootloading across x86 operating systems. In \
addition to loading the Linux kernel, it implements the Multiboot \
standard, which allows for flexible loading of multiple boot images."

HOMEPAGE = "http://www.gnu.org/software/grub/"
SECTION = "bootloaders"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=d32239bcb673463ab874e80d47fae504"

CVE_PRODUCT = "grub2"

#SRC_URI = "git://git.savannah.gnu.org/git/grub.git;protocol=https;branch=master"
#SRC_URI[sha256sum] = "afaec02c53c10df3ad3a596d07f51c74eb9c4a77ab57889fd7a15a935a56fb70"
# SRCREV = "2bc0929a2fffbb60995605db6ce46aa3f979a7d2"
#SRCREV = "29f3131a3632c70129a29d924fcb8ac98f08ee2b"

SRC_URI = "file:///home/ron/pscg/grub-2.14.1-bootstrapped-wip.tar.gz"

S = "${WORKDIR}/grub-2.14.1-bootstrapped-wip"


DEPENDS = "flex-native bison-native gettext-native"
DEPENDS += "autoconf-archive-native"

GRUB_COMPATIBLE_HOST = '(x86_64.*|i.86.*|arm.*|aarch64.*|riscv.*)-(linux.*|freebsd.*)'
COMPATIBLE_HOST = "${GRUB_COMPATIBLE_HOST}"
# Grub doesn't support hard float toolchain and won't be able to forcefully
# disable it on some of the target CPUs. See 'configure.ac' for
# supported/unsupported CPUs in hardfp.
COMPATIBLE_HOST:armv7a = "${@'null' if bb.utils.contains('TUNE_CCARGS_MFLOAT', 'hard', True, False, d) else d.getVar('GRUB_COMPATIBLE_HOST')}"
COMPATIBLE_HOST:armv7ve = "${@'null' if bb.utils.contains('TUNE_CCARGS_MFLOAT', 'hard', True, False, d) else d.getVar('GRUB_COMPATIBLE_HOST')}"

# configure.ac has code to set this automagically from the target tuple
# but the OE freeform one (core2-foo-bar-linux) don't work with that.

GRUBPLATFORM:arm = "efi"
GRUBPLATFORM:aarch64 = "efi"
GRUBPLATFORM:riscv32 = "efi"
GRUBPLATFORM:riscv64 = "efi"
GRUBPLATFORM ??= "pc"

inherit autotools gettext texinfo pkgconfig

CFLAGS:remove = "-O2"
# It doesn't support sse, its make.defaults sets:
# CFLAGS += -mno-mmx -mno-sse
# So also remove -mfpmath=sse from TUNE_CCARGS
TUNE_CCARGS:remove = "-mfpmath=sse"

EXTRA_OECONF = "--with-platform=${GRUBPLATFORM} \
                --disable-grub-mkfont \
                --program-prefix="" \
                --enable-liblzma=no \
                --enable-libzfs=no \
                --enable-largefile \
                --disable-werror \
"

PACKAGECONFIG ??= ""
PACKAGECONFIG[grub-mount] = "--enable-grub-mount,--disable-grub-mount,fuse"
PACKAGECONFIG[device-mapper] = "--enable-device-mapper,--disable-device-mapper,libdevmapper"

# grub2 creates its own set of -nostdinc / -isystem / -ffreestanding CFLAGS and
# OE's default BUILD_CFLAGS (assigned to CFLAGS for native builds) etc, conflict
# with that. Note that since BUILD_CFLAGS etc are not used by grub2 target
# builds, it's safe to clear them unconditionally for both target and native.
BUILD_CPPFLAGS = ""
BUILD_CFLAGS = ""
BUILD_CXXFLAGS = ""
BUILD_LDFLAGS = ""

export PYTHON = "python3"

# :prepend() {
do_configure:prepend() {
        bbnote "Configuring from GIT. That would be grub-2.14-rc1 ${PN}"
	cd ${S}
        bbdebug 1  "S=$S  S=${S}"
        bbdebug 1 "WORKDIR=${WORKDIR}"
        bbdebug 1 "B=${B}"

        echo "---------------------"
        ls "${WORKDIR}"
        echo "----------------------"
        ls "${S}"
        ./bootstrap --skip-po --no-git --gnulib-srcdir=${S}/gnulib
        #./autogen.sh
	cd ${B}
}
