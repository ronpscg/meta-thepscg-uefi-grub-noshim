SUMMARY = "Installs and enables custom systemd services for TPM2 provisioning"
DESCRIPTION = "Enables tpm2-provision-luks.service and installs related files."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Files are fetched from the 'files' subdirectory, maintaining their structure.
# They are relative to the 'files' directory next to the recipe.
SRC_URI = "file://etc/systemd/system/tpm2-provision-luks.service \
           file://opt/scripts/enroll-tpm2-disk.sh" 

# Ensure the package is not split by default and includes all required files

FILES_${PN} += "/opt/scripts/enroll-tpm2-disk.sh \
                ${systemd_system_unitdir}/tpm2-provision-luks.service"

FILES:${PN} += "\
    /opt \
    /opt/scripts \
    /opt/scripts/* \
"

RDEPENDS:${PN} += "bash"

# Inherit the systemd class to gain functionality for service activation
inherit systemd

# Define the source directory (where the files are unpacked/found)
S = "${WORKDIR}"

# Critical step: Tells Yocto which service units to enable automatically in the target image.
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
SYSTEMD_SERVICE:${PN} = "tpm2-provision-luks.service"

# Ensure systemd is a runtime dependency for the service to function
RDEPENDS_${PN} += "systemd"

do_install() {
    # 1. Install the Systemd Service Unit
    # ${systemd_system_unitdir} resolves to /etc/systemd/system or /lib/systemd/system
    # depending on the distribution configuration.
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/etc/systemd/system/tpm2-provision-luks.service ${D}${systemd_system_unitdir}

    # 2. Install the TPM Enrollment Script
    # The script goes to /opt/scripts/ on the target.
    install -d ${D}/opt/scripts
    install -m 0755 ${S}/opt/scripts/enroll-tpm2-disk.sh ${D}/opt/scripts/
}

