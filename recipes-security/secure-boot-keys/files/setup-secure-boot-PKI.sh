#!/bin/bash
set -euo pipefail

: ${ARTIFACTS_DIR:?ARTIFACTS_DIR not set}

KEYS_DIR="$ARTIFACTS_DIR/keys"
mkdir -p "$KEYS_DIR"
cd "$KEYS_DIR"

echo "[+] Generating keys"

# Generate PK
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI Platform Key/" \
    -keyout PK.key -out PK.crt

# Generate KEK
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI KEK/" \
    -keyout KEK.key -out KEK.crt

# Generate db
openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/O=The PSCG/CN=UEFI DB Key/" \
    -keyout db.key -out db.crt

echo "[+] Converting output to DER to keep EDK2 happy"
openssl x509 -in PK.crt -outform DER -out PK.cer
openssl x509 -in KEK.crt -outform DER -out KEK.cer
openssl x509 -in db.crt -outform DER -out db.cer

echo "[+] Creating EFI signature lists"
cert-to-efi-sig-list -g "$(uuidgen)" PK.crt PK.esl
cert-to-efi-sig-list -g "$(uuidgen)" KEK.crt KEK.esl
cert-to-efi-sig-list -g "$(uuidgen)" db.crt db.esl

echo "[+] Signing the keys"
sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl db.auth

echo "[+] Secure Boot keys created successfully in $KEYS_DIR"
