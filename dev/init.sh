#!/bin/bash

KEYS_DIR="sftp-keys"
DATA_DIR="sftp-data"

echo "Generate Keys..."
mkdir -p "${KEYS_DIR}"
# ssh-keygen -t ed25519 -f "${KEYS_DIR}/agency_ed25519_key" < /dev/null
ssh-keygen -t rsa -b 4096 -f "${KEYS_DIR}/agency_rsa_key" < /dev/null

echo "Generate Folder Structure...."
mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"
mkdir -p {1_open,2_review,3_deploy,4_done}
