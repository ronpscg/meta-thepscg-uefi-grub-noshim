# Directory where signed/verity artifacts will be placed
#do_secure_artifacts_setup[nostamp] = "1"
#do_secure_artifacts[nostamp] = "1"


# Where your scripts will be staged during the build
SECURE_SCRIPTS_DIR = "${WORKDIR}/secure-scripts"

# Ensure scripts are included
FILESEXTRAPATHS:prepend := "${THISDIR}/secure-artifacts/files:"

python do_secure_artifacts_setup() {
    import os, shutil
    bb.note("Noted Debug here")

    d.setVar("ARTIFACTS_DIR", "${DEPLOY_DIR_IMAGE}/secure-boot-work${IMAGE_VERSION_SUFFIX}")

    d = locals()['d']
    workdir = d.getVar("ARTIFACTS_DIR")

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
    bb.note("ARTIFACTS_DIR: ", workdir)
    bb.note("FILE_DIRNAME: ", files_dir)
    bb.note("SECURE_SCRIPTS_DIR: ", scripts_dir)
}

addtask do_secure_artifacts_setup before do_secure_artifacts

do_secure_artifacts2() {
    bbnote "Noted DEBUG in shell"
    echo "=== secure-artifacts: starting ==="

    mkdir -p ${ARTIFACTS_DIR}

    echo "Copying kernel: ${KERNEL_IMAGE}"
    cp ${KERNEL_IMAGE} ${ARTIFACTS_DIR}/

    echo "Copying initramfs: ${INITRAMFS_IMAGE_FULL}"
    cp ${INITRAMFS_IMAGE_FULL} ${ARTIFACTS_DIR}/

    echo "Copying rootfs: ${IMAGE_FILE}"
    cp ${IMAGE_FILE} ${ARTIFACTS_DIR}/

    echo "Copying EFI bootloader: ${EFI_BOOT_IMAGE}"
    cp ${EFI_BOOT_IMAGE} ${ARTIFACTS_DIR}/

    echo "Running secure scripts from ${SECURE_SCRIPTS_DIR}"

    cd ${ARTIFACTS_DIR}

    bbnote "Noted DEBUG in shell returning before the scripts"
    return 0
    # Example script calls — will refine later based on your exact workflow
    ${SECURE_SCRIPTS_DIR}/6-dmverity-prepare.sh || exit 1
    ${SECURE_SCRIPTS_DIR}/6-luks-prepare.sh || exit 1
    ${SECURE_SCRIPTS_DIR}/make-images.sh || exit 1

    echo "=== secure-artifacts: completed ==="
}

do_secure_artifacts2() {
    bbnote "secure-artifacts: starting"

    ARTIFACTS_DIR="${DEPLOY_DIR_IMAGE}/secure-boot-work"
    mkdir -p "${ARTIFACTS_DIR}"

    SRC_DIR="${DEPLOY_DIR_IMAGE}"
    bbnote "secure-artifacts: deploy dir ${SRC_DIR}"

    # helper: pick first existing file out of args
    pick_first() {
        for p in "$@"; do
            if [ -n "$p" ] && [ -e "$p" ]; then
                echo "$p"
                return 0
            fi
        done
        return 1
    }

    # 1) Kernel — prefer direct variables, else fallback to common filename patterns
    # Variables to try (ordered): KERNEL_IMAGE, KERNEL_BINARY, "${SRC_DIR}/*-Image*", "${SRC_DIR}/*zImage*", "${SRC_DIR}/*bzImage*", "${SRC_DIR}/*vmlinuz*"
    KERNEL_CANDIDATES=""
    # expand potential BitBake-provided variables (may be empty)
    if [ -n "${KERNEL_IMAGE}" ]; then
        KERNEL_CANDIDATES="${KERNEL_IMAGE}"
    fi
    if [ -n "${KERNEL_BINARY}" ]; then
        KERNEL_CANDIDATES="${KERNEL_CANDIDATES} ${KERNEL_BINARY}"
    fi

    # add patterns (globs will expand if matching files exist)
    for g in "${SRC_DIR}"/*-Image* "${SRC_DIR}"/*Image "${SRC_DIR}"/*zImage* "${SRC_DIR}"/*bzImage* "${SRC_DIR}"/*vmlinuz* ; do
        [ -e "$g" ] && KERNEL_CANDIDATES="${KERNEL_CANDIDATES} ${g}"
    done

    KERNEL_FILE=$(pick_first ${KERNEL_CANDIDATES})
    if [ -n "${KERNEL_FILE}" ]; then
        bbnote "secure-artifacts: copying kernel -> ${KERNEL_FILE}"
        cp -a "${KERNEL_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: kernel image NOT FOUND"
    fi

    # 2) Initramfs — prefer INITRAMFS_IMAGE_FULL / INITRAMFS_IMAGE, else patterns
    INITRAMFS_CANDIDATES=""
    [ -n "${INITRAMFS_IMAGE_FULL}" ] && INITRAMFS_CANDIDATES="${INITRAMFS_CANDIDATES} ${INITRAMFS_IMAGE_FULL}"
    [ -n "${INITRAMFS_IMAGE}" ] && INITRAMFS_CANDIDATES="${INITRAMFS_CANDIDATES} ${INITRAMFS_IMAGE}"
    for g in "${SRC_DIR}"/*initramfs* "${SRC_DIR}"/*initramfs*.cpio* "${SRC_DIR}"/*-initramfs* "${SRC_DIR}"/*initramfs*.cpio.gz ; do
        [ -e "$g" ] && INITRAMFS_CANDIDATES="${INITRAMFS_CANDIDATES} ${g}"
    done
    INITRAMFS_FILE=$(pick_first ${INITRAMFS_CANDIDATES})
    if [ -n "${INITRAMFS_FILE}" ]; then
        bbnote "secure-artifacts: copying initramfs -> ${INITRAMFS_FILE}"
        cp -a "${INITRAMFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: initramfs NOT FOUND (this may be normal if you didn't build one)"
    fi

    if false ; then
    # 3) Rootfs — prefer IMAGE_FILE / IMAGE_ROOTFS / IMAGE_LINK_NAME.* , else search for rootfs.* or *.ext4/squashfs
    ROOTFS_CANDIDATES=""
    [ -n "${IMAGE_FILE}" ] && ROOTFS_CANDIDATES="${ROOTFS_CANDIDATES} ${IMAGE_FILE}"
    [ -n "${IMAGE_ROOTFS}" ] && ROOTFS_CANDIDATES="${ROOTFS_CANDIDATES} ${IMAGE_ROOTFS}"
    # symlink name (image link name) can help
    if [ -n "${IMAGE_LINK_NAME}" ]; then
        for ext in ext4 squashfs tar.bz2 tar.gz wic cpio.gz; do
            p="${SRC_DIR}/${IMAGE_LINK_NAME}.rootfs.${ext}"
            [ -e "$p" ] && ROOTFS_CANDIDATES="${ROOTFS_CANDIDATES} ${p}"
        done
    fi

    # Folders are problematic because of the fakeroot. The image itself - for whatever reason is not identical to what is inside the wic image, so I'll
    # need to look at it (I thought I disabled WIC creation). I'll look at it later. So choose the ext4 folder I made there.
    #for g in "${SRC_DIR}"/*.rootfs* "${SRC_DIR}"/*.ext4 "${SRC_DIR}"/*.wic "${SRC_DIR}"/*.squashfs "${SRC_DIR}"/*.tar.gz; do
    for g in "${SRC_DIR}"/*.ext4 ; do
        [ -e "$g" ] && ROOTFS_CANDIDATES="${ROOTFS_CANDIDATES} ${g}"
    done
    ROOTFS_FILE=$(pick_first ${ROOTFS_CANDIDATES})
    if [ -n "${ROOTFS_FILE}" ]; then
        bbnote "secure-artifacts: copying rootfs -> ${ROOTFS_FILE}"
        cp -a "${ROOTFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: rootfs NOT FOUND"
    fi

    fi
      
    ROOTFS_FILE=$SRC_DIR/${IMAGE_LINK_NAME}.ext4
    bbnote "secure-artifacts: copying rootfs -> ${ROOTFS_FILE}"
    cp $SRC_DIR/${IMAGE_LINK_NAME}.ext4 ${ARTIFACTS_DIR}/

    # 4) EFI/GRUB — try EFI_BOOT_IMAGE, EFI_IMAGE_NAME, else search for grub-*.efi or *-efi-*.efi
    EFI_CANDIDATES=""
    [ -n "${EFI_BOOT_IMAGE}" ] && EFI_CANDIDATES="${EFI_CANDIDATES} ${EFI_BOOT_IMAGE}"
    [ -n "${EFI_IMAGE_NAME}" ] && EFI_CANDIDATES="${EFI_CANDIDATES} ${SRC_DIR}/${EFI_IMAGE_NAME}"
    for g in "${SRC_DIR}"/*grub*.efi "${SRC_DIR}"/*efi-boot* "${SRC_DIR}"/*-efi-*.efi "${SRC_DIR}"/*-bootx64*.efi "${SRC_DIR}"/*-bootia32*.efi ; do
        [ -e "$g" ] && EFI_CANDIDATES="${EFI_CANDIDATES} ${g}"
    done
    EFI_FILE=$(pick_first ${EFI_CANDIDATES})
    if [ -n "${EFI_FILE}" ]; then
        bbnote "secure-artifacts: copying efi/grub -> ${EFI_FILE}"
        cp -a "${EFI_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: EFI/GRUB image NOT FOUND (maybe your build doesn't produce one)"
    fi

    bbnote "secure-artifacts: finished - artifacts placed in ${ARTIFACTS_DIR}"

    return 0
}

#
# Copy images to a staging work dir, where we will sign everything and produce the secure images
# We copy the link targets, not the links themselves. If you mess up with sstate cache, you may find they are not pointing where you expect. Otherwise it's all good
#
do_secure_artifacts() {
    bbnote "secure-artifacts: starting"

    #ARTIFACTS_DIR="${DEPLOY_DIR_IMAGE}/secure-boot-work"
    ARTIFACTS_DIR="${DEPLOY_DIR_IMAGE}/secure-boot-work${IMAGE_VERSION_SUFFIX}"
    echo "ARTIFACTS_DIR is ${ARTIFACTS_DIR}"
    mkdir -p "${ARTIFACTS_DIR}"

    SRC_DIR="${DEPLOY_DIR_IMAGE}"
    bbnote "secure-artifacts: deploy dir ${SRC_DIR}"
    cd $SRC_DIR
    
    KERNEL_FILE=${KERNEL_IMAGETYPE}
    if [ -n "${KERNEL_FILE}" ]; then
        bbnote "secure-artifacts: copying kernel -> ${KERNEL_FILE}"
        cp "${KERNEL_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: kernel image NOT FOUND"
    fi

    # 2) Initramfs — prefer INITRAMFS_IMAGE_FULL / INITRAMFS_IMAGE, else patterns
    INITRAMFS_FILE=${INITRAMFS_IMAGE}-${MACHINE}.cpio.gz  # need to rename the suffix probably
    if [ -n "${INITRAMFS_FILE}" ]; then
        bbnote "secure-artifacts: copying initramfs -> ${INITRAMFS_FILE}"
        cp "${INITRAMFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: initramfs NOT FOUND (this may be normal if you didn't build one)"
    fi

    ROOTFS_FILE=$SRC_DIR/${IMAGE_LINK_NAME}.ext4
    if [ -n "${ROOTFS_FILE}" ]; then
        bbnote "secure-artifacts: copying rootfs -> ${ROOTFS_FILE}"
        cp "${ROOTFS_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbwarn "secure-artifacts: rootfs NOT FOUND"
    fi
    
    EFI_FILE=${EFI_PROVIDER}-bootx64.efi
    if [ -n "${EFI_FILE}" ]; then
        bbnote "secure-artifacts: copying efi/grub -> ${EFI_FILE}"
        cp "${EFI_FILE}" "${ARTIFACTS_DIR}/"
    else
        bbnote "secure-artifacts: EFI/GRUB image NOT FOUND (maybe your build doesn't produce one)"
    fi

    ln -sTf $(basename ${ARTIFACTS_DIR}) ${DEPLOY_DIR_IMAGE}/secure-boot-work
    bbnote "secure-artifacts: finished - artifacts placed in ${ARTIFACTS_DIR}"

    return 0
}

addtask do_secure_artifacts after do_image_complete before do_build

