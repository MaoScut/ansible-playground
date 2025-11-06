#!/usr/bin/env bash
set -euo pipefail

ROLE=${ROLE:-worker}
SSH_USER="ansible"
HOME_DIR="/home/${SSH_USER}"
SSH_DIR="${HOME_DIR}/.ssh"
SHARED_DIR="/shared-ssh"

echo "[entrypoint] starting in role: ${ROLE}" >&2

mkdir -p /var/run/sshd
mkdir -p "${SSH_DIR}"
chown "${SSH_USER}:${SSH_USER}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [[ ! -d "${SHARED_DIR}" ]]; then
  echo "[entrypoint] shared directory ${SHARED_DIR} not found" >&2
  exit 1
fi

AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
touch "${AUTHORIZED_KEYS}"
chown "${SSH_USER}:${SSH_USER}" "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"

CONFIG_FILE="${SSH_DIR}/config"
cat > "${CONFIG_FILE}" <<'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
chown "${SSH_USER}:${SSH_USER}" "${CONFIG_FILE}"
chmod 600 "${CONFIG_FILE}"

KEY_BASENAME="controller_ed25519"
PUB_PATH="${SHARED_DIR}/${KEY_BASENAME}.pub"

if [[ "${ROLE}" == "controller" ]]; then
  echo "[entrypoint] configuring controller ssh key" >&2
  KEY_PATH="${SHARED_DIR}/${KEY_BASENAME}"
  if [[ ! -f "${KEY_PATH}" || ! -f "${PUB_PATH}" ]]; then
    echo "[entrypoint] missing shared ssh key files under ${SHARED_DIR}" >&2
    exit 1
  fi

  install -o "${SSH_USER}" -g "${SSH_USER}" -m 600 "${KEY_PATH}" "${SSH_DIR}/id_rsa"
  install -o "${SSH_USER}" -g "${SSH_USER}" -m 644 "${PUB_PATH}" "${SSH_DIR}/id_rsa.pub"

  # Ensure controller can SSH into workers via convenient host aliases.
  cat > "${CONFIG_FILE}" <<'EOF'
Host worker1
    HostName worker1
    User ansible
Host worker2
    HostName worker2
    User ansible
Host worker*
    User ansible
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
  chown "${SSH_USER}:${SSH_USER}" "${CONFIG_FILE}"
  chmod 600 "${CONFIG_FILE}"
fi

if [[ "${ROLE}" == "worker" ]]; then
  echo "[entrypoint] waiting for controller public key" >&2
  until [[ -f "${PUB_PATH}" ]]; do
    sleep 1
  done
fi

if [[ -f "${PUB_PATH}" ]]; then
  if ! grep -q -F "$(cat "${PUB_PATH}")" "${AUTHORIZED_KEYS}"; then
    cat "${PUB_PATH}" >> "${AUTHORIZED_KEYS}"
    chown "${SSH_USER}:${SSH_USER}" "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    echo "[entrypoint] authorized controller key for ${SSH_USER}" >&2
  fi
fi

ssh-keygen -A >/dev/null 2>&1

echo "[entrypoint] launching sshd" >&2
exec /usr/sbin/sshd -D -e

