#!/bin/bash
set -e

: ${ARTIFACTS_DIR:?ARTIFACTS_DIR not set}
: ${GRUB_GPG_KEY_ID:?GRUB_GPG_KEY_ID not set}
: ${GRUB_PGP_PUBLIC_KEY:?GRUB_PGP_PUBLIC_KEY not set}

if [ -f $GRUB_PGP_PUBLIC_KEY ] ; then
	# It doesn't really matter, as grub depends in this config file variable and will fail the build before we start
	# Since this is just a reference tool, it is OK. I think we should create keys prior to that - or otherwise, have clean recipes that create the keys
	echo "Key already exits. If you want to delete the file - please do it manually!"
	exit 1
fi
echo "[+] Exporting GPG key $GRUB_GPG_KEY_ID to $GRUB_PGP_PUBLIC_KEY"
gpg --batch --no-tty --export -o "$GRUB_PGP_PUBLIC_KEY" "$GRUB_GPG_KEY_ID"

if [ ! -f "$GRUB_PGP_PUBLIC_KEY" ]; then
    echo "ERROR: Failed to export GPG key"
    exit 1
fi

echo "[+] GRUB GPG public key exported successfully"
