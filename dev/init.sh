#!/bin/bash

set -euo pipefail

KEYS_DIR="sftp-keys"
DATA_DIR="sftp-data"
CONFIG_DIR="sftp-config"
CONFIG="${CONFIG_DIR}/users.conf"

AGENCIES="agency1 agency2 agency3"

function print_ok_failed() {
    if [[ ${1} == 0 ]]; then
        echo -e "\033[42mOK\033[0m"
    else
        echo -e "\033[41mFAILED\033[0m"
    fi
}

cd "$(dirname "${BASH_SOURCE[0]}")"

echo -n "Cleanup folders...              "
rm -rf ${KEYS_DIR}/* ${DATA_DIR}/* ${CONFIG_DIR}/*
print_ok_failed $?

echo -n "Generate Host Keys...           "
mkdir -p "${KEYS_DIR}"
mkdir -p "${KEYS_DIR}/host"
ssh-keygen -N '' -t ed25519 -f "${KEYS_DIR}/host/ed25519_key" <<< y > /dev/null
ssh-keygen -N '' -t rsa -b 4096 -f "${KEYS_DIR}/host/rsa_key" <<< y > /dev/null
print_ok_failed $?

echo -n "Generate Folder Structure....   "
for agency in ${AGENCIES}; do
    mkdir -p "${DATA_DIR}/${agency}"/{1_open,2_deploy,3_done}
done
print_ok_failed $?

echo -n "Generate Agency Keys...         "
mkdir -p "${CONFIG_DIR}"
uid=1001
gid=1000
for agency in ${AGENCIES}; do
    mkdir -p "${KEYS_DIR}/${agency}"
    # ssh-keygen -t ed25519 -f "${KEYS_DIR}/${agency}/ed25519_key" < /dev/null
    ssh-keygen -N '' -t rsa -b 4096 -f "${KEYS_DIR}/${agency}/rsa_key" <<< y > /dev/null
    echo "${agency}::${uid}:${gid}" >> "${CONFIG}"
    ((uid++))
done
print_ok_failed $?

