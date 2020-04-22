#!/bin/bash

KEYS_DIR="sftp-keys"

mkdir -p "${KEYS_DIR}"
ssh-keygen -t ed25519 -f "${KEYS_DIR}/agency_ed25519_key" < /dev/null
ssh-keygen -t rsa -b 4096 -f "${KEYS_DIR}/agency_rsa_key" < /dev/null
