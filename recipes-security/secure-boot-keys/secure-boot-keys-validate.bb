# Logfile:  
# ~/yocto/build-scarthgap-x86_64/tmp/work/x86_64-linux/secure-boot-keys-validate/1.0/temp/do_configure.log

SUMMARY = "Validate that Secure Boot keys exist before building"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# This is a native recipe - runs on build host
inherit native

# Make this run very early - it's just validation
do_fetch[noexec] = "1"
do_unpack[noexec] = "1"
do_patch[noexec] = "1"

# Fail fast - run this before configure
do_configure[prefuncs] += "validate_keys"

python validate_keys() {
    import os
    
    artifacts_dir = d.getVar('SECURE_BOOT_ARTIFACTS_DIR')
    if not artifacts_dir:
        bb.fatal("SECURE_BOOT_ARTIFACTS_DIR is not set. Please set it in local.conf")
    
    artifacts_dir = os.path.expanduser(artifacts_dir)
    
    # Check GRUB GPG key
    grub_pubkey = os.path.join(artifacts_dir, "grub-pubkey.gpg")
    if not os.path.exists(grub_pubkey):
        bb.fatal(f"GRUB public key not found at: {grub_pubkey}\nRun 'bitbake secure-boot-keys-prepare -c setup_grub_pki' to create it")
    
    # Check Secure Boot keys
    #keys_dir = os.path.join(artifacts_dir, "keys")
    keys_dir = artifacts_dir # might change later, for now put in conf as it is easier for me to modify things
    required_keys = [
        "PK.key", "PK.crt", "PK.cer", "PK.esl", "PK.auth",
        "KEK.key", "KEK.crt", "KEK.cer", "KEK.esl", "KEK.auth",
        "db.key", "db.crt", "db.cer", "db.esl", "db.auth"
    ]
    
    missing = []
    for key in required_keys:
        key_path = os.path.join(keys_dir, key)
        if not os.path.exists(key_path):
            missing.append(key)
    
    if missing:
        bb.fatal(f"Missing Secure Boot keys in {keys_dir}:\n  " + "\n  ".join(missing) +
                 f"\n\nRun 'bitbake secure-boot-keys-prepare -c setup_secureboot_pki' to create them")
    
    bb.note("✓ All Secure Boot keys validated successfully")
    bb.note(f"  GRUB key: {grub_pubkey}")
    bb.note(f"  Secure Boot keys: {keys_dir}")
}

do_compile() {
    :
}

do_install() {
    :
}
