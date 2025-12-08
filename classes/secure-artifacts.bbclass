# Directory where signed/verity artifacts will be placed
#do_secure_artifacts_setup[nostamp] = "1"
#do_secure_artifacts[nostamp] = "1"


# Where your scripts will be staged during the build
SECURE_SCRIPTS_DIR = "${WORKDIR}/secure-scripts"
SECURE_ARTIFACTS_BASE_WORKDIR = "${DEPLOY_DIR_IMAGE}/secure-boot-work${IMAGE_VERSION_SUFFIX}"
SECURE_ARTIFACTS_BASE_SYMLINK = "${DEPLOY_DIR_IMAGE}/secure-boot-work"

# Ensure scripts are included
FILESEXTRAPATHS:prepend := "${THISDIR}/secure-artifacts/files:"

python do_secure_artifacts_setup() {
    import os, shutil
    bb.note("Noted Debug here")

    #d.setVar("ARTIFACTS_DIR", "${DEPLOY_DIR_IMAGE}/secure-boot-work${IMAGE_VERSION_SUFFIX}")

    #d = locals()['d']
    workdir = d.getVar("SECURE_ARTIFACTS_BASE_WORKDIR")

    # Create secure artifact output directory
    if not os.path.exists(workdir):
        os.makedirs(workdir)

    # Stage scripts into WORKDIR
    scripts_dir = d.getVar("SECURE_SCRIPTS_DIR")
    if not os.path.exists(scripts_dir):
        os.makedirs(scripts_dir)

    # Copy everything from files/ into WORKDIR
    files_dir = d.getVar('FILE_DIRNAME')
    for f in os.listdir(files_dir):
        src = os.path.join(files_dir, f)
        dst = os.path.join(scripts_dir, f)
        if os.path.isfile(src):
            shutil.copy(src, dst)
            os.chmod(dst, 0o755)
    bb.note("Noted Debug there")
    bb.note("SECURE_ARTIFACTS_BASE_WORKDIR: ", workdir)
    bb.note("FILE_DIRNAME: ", files_dir)
    bb.note("SECURE_SCRIPTS_DIR: ", scripts_dir)
}

addtask do_secure_artifacts_setup before do_secure_artifacts

#
# Copy images to a staging work dir, where we will sign everything and produce the secure images
# We copy the link targets, not the links themselves. If you mess up with sstate cache, you may find they are not pointing where you expect. Otherwise it's all good
#
do_secure_artifacts() {
    bbnote "secure-artifacts: starting"

    ARTIFACTS_DIR="${SECURE_ARTIFACTS_BASE_WORKDIR}/artifacts"
    REQUIRED_PROJECTS_ARTIFACTS_DIR="${SECURE_ARTIFACTS_BASE_WORKDIR}/required-artifacts"
    echo "ARTIFACTS_DIR is ${ARTIFACTS_DIR}"
    mkdir -p "${ARTIFACTS_DIR}"

    SRC_DIR="${DEPLOY_DIR_IMAGE}"
    bbnote "secure-artifacts: deploy dir ${SRC_DIR}"
    cd $SRC_DIR
    
    KERNEL_FILE=${KERNEL_IMAGETYPE}
    if [ -L "${KERNEL_FILE}" ]; then
        bbnote "secure-artifacts: copying kernel -> ${KERNEL_FILE}"
        cp "${KERNEL_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: kernel image NOT FOUND"
    fi

    INITRAMFS_FILE=${INITRAMFS_IMAGE}-${MACHINE}.cpio.gz  # need to rename the suffix probably, to depend on variable initramfs type/suffix
    if [ -L "${INITRAMFS_FILE}" ]; then
        bbnote "secure-artifacts: copying initramfs -> ${INITRAMFS_FILE}"
        cp "${INITRAMFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: initramfs ${INITRAMFS_FILE} NOT FOUND (this may be normal if you didn't build one)"
    fi

    if [ -L "${INITRAMFS_IMAGE_CUSTOM}" ]; then
        bbnote "secure-artifacts: copying initramfs -> ${INITRAMFS_IMAGE_CUSTOM}"
        cp "${INITRAMFS_IMAGE_CUSTOM}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: initramfs ${INITRAMFS_IMAGE_CUSTOM} NOT FOUND (this may be normal if you didn't build one)"
    fi

    ROOTFS_FILE=$SRC_DIR/${IMAGE_LINK_NAME}.ext4
    if [ -L "${ROOTFS_FILE}" ]; then
        bbnote "secure-artifacts: copying rootfs -> ${ROOTFS_FILE}"
        cp "${ROOTFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: rootfs NOT FOUND"
    fi
    
    EFI_FILE=${EFI_PROVIDER}-bootx64.efi
    if [ -f "${EFI_FILE}" ]; then
        bbnote "secure-artifacts: copying efi/grub -> ${EFI_FILE}"
        cp "${EFI_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: EFI/GRUB image ${EFI_FILE} NOT FOUND (maybe your build doesn't produce one)"
    fi

    ln -sTf $(basename ${SECURE_ARTIFACTS_BASE_WORKDIR}) ${SECURE_ARTIFACTS_BASE_SYMLINK}
    bbnote "secure-artifacts: finished - artifacts placed in ${ARTIFACTS_DIR}"

    # It's just interim, but TODO when I change that, move the REQUIRED_PROJE... up
    bbdebug 3 "Copying to required-artifacts to be consistent with the script - but the script will be changed later"
    mkdir -p $REQUIRED_PROJECTS_ARTIFACTS_DIR
    cp $ARTIFACTS_DIR/* $REQUIRED_PROJECTS_ARTIFACTS_DIR/



    return 0
}

addtask do_secure_artifacts after do_image_complete before do_build

