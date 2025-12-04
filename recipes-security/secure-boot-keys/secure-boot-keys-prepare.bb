SUMMARY = "Prepare PKI keys for Secure Boot (manual task)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit native

#DEPENDS = "efitools-native"

# Won't bother adding recipes or troubleshooting other layers. If it is wanted later, one can add the respective-native reicipes
HOSTTOOLS:append = " gpg openssl cert-to-efi-sig-list uuidgen sbsign "

SRC_URI = "file://setup-grub-PKI.sh \
           file://setup-secure-boot-PKI.sh"

S = "${WORKDIR}"

# Don't run these automatically
do_compile[noexec] = "1"
do_install[noexec] = "1"

# Manual tasks - user runs these explicitly
addtask setup_grub_pki after do_unpack
addtask setup_secureboot_pki after do_unpack

do_setup_grub_pki() {
    export ARTIFACTS_DIR="${SECURE_BOOT_ARTIFACTS_DIR}"
    export GRUB_GPG_KEY_ID="${SECURE_BOOT_GRUB_GPG_KEY_ID}"
    export GRUB_PGP_PUBLIC_KEY="${ARTIFACTS_DIR}/grub-pubkey.gpg"
    
    mkdir -p ${ARTIFACTS_DIR}
    
    bash ${WORKDIR}/setup-grub-PKI.sh
}

do_setup_secureboot_pki() {
    export ARTIFACTS_DIR="${SECURE_BOOT_ARTIFACTS_DIR}"
    
    mkdir -p ${ARTIFACTS_DIR}/keys

        # Debug: show PATH and check for openssl
    bbnote "Current PATH: $PATH"
    bbnote "Looking for openssl..."
    which openssl || bbnote "openssl not found in PATH"
    bbnote "Looking for cert-to-efi-sig-list..."
    which cert-to-efi-sig-list || bbnote "cert-to-efi-sig-list not found in PATH"

    
    export PATH="${STAGING_BINDIR_NATIVE}:${STAGING_BINDIR_NATIVE}/../../hosttools:${PATH}"

    bash ${WORKDIR}/setup-secure-boot-PKI.sh
}
