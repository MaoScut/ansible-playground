#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET_DIR="${ROOT_DIR}/ssh-keys"
KEY_NAME="controller_ed25519"
KEY_PATH="${TARGET_DIR}/${KEY_NAME}"
PUB_PATH="${KEY_PATH}.pub"

mkdir -p "${TARGET_DIR}"
chmod 700 "${TARGET_DIR}"

if [[ -f "${KEY_PATH}" && -f "${PUB_PATH}" ]]; then
  echo "[prepare-ssh-keys] key pair already exists at ${KEY_PATH}"
  exit 0
fi

echo "[prepare-ssh-keys] generating ed25519 key pair at ${KEY_PATH}" >&2
ssh-keygen -t ed25519 -f "${KEY_PATH}" -q -N "" -C "controller@ansible-playground"
chmod 600 "${KEY_PATH}"
chmod 644 "${PUB_PATH}"

echo "[prepare-ssh-keys] done" >&2

