SUMMARY = "Builds initramfs using Dracut inside a defined Docker container"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "git://github.com/ronpscg/initramfs-builder-for-systemd-dmcrypt-dmverity-tpm2-unlocker;protocol=https;branch=docker"
SRCREV ="${AUTOREV}"

DOCKER_IMAGE = "fedora-yocto-initramfs-builder:latest"
INITRD_IMG = "${WORKDIR}/git/workdir/fedora/initrd.img"

S = "${WORKDIR}/git"

check_docker() {
    if [ -f /.dockerenv ] ; then
        bbnote "In docker"
        return 0
    else 
        bbnote "Not in docker"
        return 1
    fi
}

do_configure() {
    cd ${S}

    # Running HOSTTOOLS tools in external scripts *sometimes* requires adding and exporting the path to the script
    #export PATH="${STAGING_BINDIR_NATIVE}:${STAGING_BINDIR_NATIVE}/../../hosttools:${PATH}"
    # We don't need this now because I just do the setup-and-build here, to avoid modifying the file for non-tty devices (e.g. the Yocto Project build)

    bbnote "Using docker version $(docker --version)" # if docker is not supported it will fail here
    bbnote "Configure: building the docker image"
    if ! check_docker ; then 
        docker build -t ${DOCKER_IMAGE} -f Dockerfile.fedora .
    else
        docker build -t ${DOCKER_IMAGE} -f Dockerfile.fedora.no-bind-mounts .
    fi
    bbnote "${DOCKER_IMAGE} set up successfully"
}

do_compile() {
    # No need to check failures, as failing steps would result in 
    cd ${S}
    initrd_artifact="${S}/workdir/fedora/initrd.img"
    if ! check_docker ; then
        DOCKER_RUN_CMD="docker run --rm -i -w /host -v $PWD/workdir/fedora:/host ${DOCKER_IMAGE}"
        if $DOCKER_RUN_CMD bash -c "./build.sh && chmod a+rw /host/initrd.img" ; then
            bbnote "Built initramfs successfully.  $(md5sum $initrd_artifact)"
        fi
    else
        dockername=yocto-initramfs-builder
        DOCKER_RUN_CMD="docker run --name $dockername --rm -d  -w /host ${DOCKER_IMAGE}"
        if [ $(docker ps -f name=$dockername | wc -l) -gt 1 ] ; then
            bbwarn "Killing previous dockers: $(docker ps -f name=$dockername)"
            docker stop $dockername # this could take a while but it is more reliable then killing and contiuing directly
        fi
        $DOCKER_RUN_CMD /bin/bash -c "while true ; do sleep 1000 ; done"
        if docker exec -i $dockername bash -c "./build.sh && chmod a+rw /host/initrd.img" ; then
            if docker cp $dockername:/host/initrd.img $initrd_artifact ; then
                bbnote "Built initramfs successfully.  $(md5sum $initrd_artifact)"
                docker kill $dockername
            else
                docker kill $dockername
                bbfatal "Failed to copy the file"
            fi
        else
            docker kill $dockername
            bbfatal "Failed to create initramfs"
        fi
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

inherit deploy
addtask deploy before do_build after do_compile
