#
# Note: The GRUB public key does not need to be secret, so it is not destroyed after usage (as it can be useful for debugging a built if something goes wrong)
#       When private keys are entailed, more caution needs to be involved
#
FILESPATH:prepend := "${THISDIR}/files/grub-configs:"
FILESPATH:prepend := "${HOST_PROVIDED_KEYS}:"

SRC_URI += " \
           file://${GRUB_CONFIG} \
           file://${GRUB_PGP_PUBLIC_KEY} \
          "

# S = "${WORKDIR}/grub-${PV}"

# Determine the target arch for the grub modules
python __anonymous () {
        print('\x1b[45mHi from bbappend file\x1b[0m')
}


mkimage_helper_embedded_config_helper() {
	cd $GRUB_BUILDER_DIR
	# Create the memdisk filesystem. You get it for granted in the standalone version
	# Don't use mktemp, and leave the tarball for debugging if someone wants. This is not the best practice but if you run into issues with it
	# it is definitely "your fault" and you know what you are doing
	rm -rf /tmp/grub-memdisk-workdir/
	mkdir -p /tmp/grub-memdisk-workdir/boot/grub/
	cp $GRUB_CONFIG /tmp/grub-memdisk-workdir/boot/grub/grub.cfg
	( cd /tmp/grub-memdisk-workdir && tar cf /tmp/grub-memdisk.tar . && tar tf /tmp/grub-memdisk.tar )

	# grub-mkimage requires specifying modules explicitly
	# minicmd has help, lsmod etc. One could include help, but there is no module for lsmod
	: ${GRUB_MODULES="
		part_gpt part_msdos ext2 linux normal boot memdisk configfile search fat ls cat echo test gcry_dsa gcry_rsa gcry_sha256 pubkey pgp \
		tar minicmd efifwsetup
		tpm \
	"}
        #--------------------
        echo "--------------------"
        echo "Will build $GRUB_CONFIG , $GRUB_MODULES  . PWD=$PWD  pwd=$(pwd)"
        echo "GRUB_GPG_KEY_ID=${GRUB_GPG_KEY_ID},  GRUB_GPG_KEY_ID=$GRUB_GPG_KEY_ID"
        echo "--------------------"
        #--------------------
	grub-mkimage -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} --directory=./grub-core \
		--disable-shim-lock \
		--pubkey=$GRUB_PGP_PUBLIC_KEY \
		-m /tmp/grub-memdisk.tar \
		$GRUB_MODULES

        return

        # Their grub-mkimage, for a reference:
	grub-mkimage -v -c ../cfg -p ${EFIDIR} -d ./grub-core/ \
	               -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} \
	               ${GRUB_MKIMAGE_MODULES}
}

mkimage_helper_embedded_config_helper_nonstandalone() {
        # Build a non standalone GRUB, so that we can sign the config file in a post step, and also align to other versions of GRUB if need be
	cd $GRUB_BUILDER_DIR
	# grub-mkimage requires specifying modules explicitly
	# minicmd has help, lsmod etc. One could include help, but there is no module for lsmod
	: ${GRUB_MODULES="
		part_gpt part_msdos ext2 linux normal boot memdisk configfile search fat ls cat echo test gcry_dsa gcry_rsa gcry_sha256 pubkey pgp \
		tar minicmd efifwsetup
		tpm hello lspci pcidump random \
	"}

        GRUB_MODULES="$GRUB_MODULES  "
	: ${GRUB_TARGET_CONFIG_FILE_PREFIX_DIR="/EFI/Boot"}
	grub-mkimage -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} --directory=./grub-core \
		--disable-shim-lock \
		--pubkey=$GRUB_PGP_PUBLIC_KEY \
		--prefix=$GRUB_TARGET_CONFIG_FILE_PREFIX_DIR \
		$GRUB_MODULES

        bbdebug 2 "This was the command \ 
	grub-mkimage -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} --directory=./grub-core \
		--disable-shim-lock \
		--pubkey=$GRUB_PGP_PUBLIC_KEY \
		--prefix=$GRUB_TARGET_CONFIG_FILE_PREFIX_DIR \
		$GRUB_MODULES"

        return

        # Their grub-mkimage, for a reference:
	grub-mkimage -v -c ../cfg -p ${EFIDIR} -d ./grub-core/ \
	               -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} \
	               ${GRUB_MKIMAGE_MODULES}
}
do_mkimage() {


        # can do something more accurate about adding modules, but I'll just do the exact selection in the reference scripts
	
        cd ${B}

	GRUB_MKIMAGE_MODULES="${GRUB_BUILDIN}"

	# If 'all' is included in GRUB_BUILDIN we will include all available grub2 modules
	if [ "${@ bb.utils.contains('GRUB_BUILDIN', 'all', 'True', 'False', d)}" = "True" ]; then
		bbdebug 1 "Including all available modules"
		# Get the list of all .mod files in grub-core build directory
		GRUB_MKIMAGE_MODULES=$(find ${B}/grub-core/ -type f -name "*.mod" -exec basename {} .mod \;)
	fi


        echo -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        bbplain -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        bbnote -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        bbdebug 1 -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        bbdebug 2 -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        bbdebug 3 -e "\x1b[42m Making the image - SLIGHTLY overriding\x1b[0m"
        
        # The problem with the ../cfg file is that it is parsed *VERY* early during the boot, before loading modules, and most of the things you need are not available there.
        # cat ../cfg # I removed cfg, I embedded a file instead

        echo "S=${S}"
        ls "${S}"

        bbnote "Welding ${GRUB_CONFIG} into your your standalone, grub-mkimage made file"
        bbdebug 1 "Using GRUB config from ${WORKDIR}/${GRUB_CONFIG}"
        GRUB_CONFIG=${WORKDIR}/${GRUB_CONFIG}
        GRUB_GPG_KEY_ID=${GRUB_GPG_KEY_ID}
        GRUB_PGP_PUBLIC_KEY=${WORKDIR}/${GRUB_PGP_PUBLIC_KEY}
        ls -l ${WORKDIR}

        # Careful: inside shell scripts $VAR and ${VAR} will not behave the same (in bitake!). So $GRUB_CONFIG is what we assigned - do not use in this case ${GRUB_CONFIG}
        #          as it is what would come from the outer environment!
        cat $GRUB_CONFIG
         


        GRUB_BUILDER_DIR=${B}
        #GRUB_CONFIG=
        which grub-mkimage
        echo "*********************** ABOUT TO BUILD MY OWN GRUB ************************"
        bbnote "standalone=${GRUB_BUILD_STANDALONE_IMAGE}"
        if [ "${GRUB_BUILD_STANDALONE_IMAGE}" = "true" ] ; then
            mkimage_helper_embedded_config_helper
        else
            mkimage_helper_embedded_config_helper_nonstandalone
        fi
        #bberror "not ready yet"
        return
	# Search for the grub.cfg on the local boot media by using the
	# built in cfg file provided via this recipe
	grub-mkimage -v -c ../cfg -p ${EFIDIR} -d ./grub-core/ \
	               -O ${GRUB_TARGET}-efi -o ./${GRUB_IMAGE_PREFIX}${GRUB_IMAGE} \
	               ${GRUB_MKIMAGE_MODULES}
}

# addtask mkimage before do_install after do_compile
