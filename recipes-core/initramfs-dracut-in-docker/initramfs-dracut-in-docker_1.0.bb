SUMMARY = "Builds initramfs using Dracut inside a defined Docker container"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "git://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker;protocol=https;branch=master"
SRCREV ="b51dd164fb82cbf71d28b0eeef91848c491060e6"

DOCKER_IMAGE = "fedora-yocto-initramfs-builder:latest"
INITRD_IMG = "${WORKDIR}/git/workdir/fedora/initrd.img"

S = "${WORKDIR}/git"

do_configure() {
    cd ${S}

    # Running HOSTTOOLS tools in external scripts *sometimes* requires adding and exporting the path to the script
    #export PATH="${STAGING_BINDIR_NATIVE}:${STAGING_BINDIR_NATIVE}/../../hosttools:${PATH}"
    # We don't need this now because I just do the setup-and-build here, to avoid modifying the file for non-tty devices (e.g. the Yocto Project build)

    bbnote "Using docker version $(docker --version)" # if docker is not supported it will fail here
    bbnote "Configure: building the docker image"
    docker build -t ${DOCKER_IMAGE} -f Dockerfile.fedora .
    bbnote "${DOCKER_IMAGE} set up successfully"
}

do_compile() {
    cd ${S}
    DOCKER_RUN_CMD="docker run --rm -i -w /host -v $PWD/workdir/fedora:/host ${DOCKER_IMAGE}"
    if $DOCKER_RUN_CMD bash -c "./build.sh && chmod a+rw /host/initrd.img" ; then
        initrd_artifact="${S}/workdir/fedora/initrd.img"
        bbnote "Built initramfs successfully.  $(md5sum $initrd_artifact)"
    else
	echo -e "\e[31mFailed to build your initramfs image\e[0m"
    fi
}


do_install() {
    :
}

do_deploy() {
    if [ ! -f "${INITRD_IMG}" ]; then
        bbfatal "Initrd image not found at ${INITRD_IMG}. Docker build failed."
    fi

    install -m 0644 ${INITRD_IMG} ${DEPLOY_DIR_IMAGE}/${PN}.initrd.img
    
    cd ${DEPLOY_DIR_IMAGE}
    ln -sf ${PN}.initrd.img initrd.img
}

addtask deploy before do_build after do_compile

