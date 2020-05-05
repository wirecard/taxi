#!/bin/bash

KEYS_DIR="sftp-keys"
DATA_DIR="sftp-data"

function print_ok_failed() {
  if [[ ${1} == 0 ]]; then
    echo -e "\033[42mOK\033[0m"
  else
    echo -e "\033[41mFAILED\033[0m"
  fi
}

echo -n "Generate Keys...                "
mkdir -p "${KEYS_DIR}"
# ssh-keygen -t ed25519 -f "${KEYS_DIR}/agency_ed25519_key" < /dev/null
ssh-keygen -N '' -t rsa -b 4096 -f "${KEYS_DIR}/agency_rsa_key" <<< y > /dev/null
print_ok_failed $?

echo -n "Generate Folder Structure....   "
mkdir -p "${DATA_DIR}"/{1_open,2_review,3_deploy,4_done}
print_ok_failed $?
