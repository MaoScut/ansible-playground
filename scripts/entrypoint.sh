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

  # Configure DNAT rules if specified
  DNAT_CONFIG_FILE="${DNAT_CONFIG_FILE:-/etc/dnat-rules.conf}"
  DNAT_RULES_ARRAY=()
  
  # Load DNAT rules from config file (priority) or environment variable (fallback)
  if [[ -f "${DNAT_CONFIG_FILE}" ]]; then
    echo "[entrypoint] loading DNAT rules from ${DNAT_CONFIG_FILE}" >&2
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      line=$(echo "$line" | sed 's/#.*//' | xargs)
      if [[ -n "$line" ]]; then
        DNAT_RULES_ARRAY+=("$line")
      fi
    done < "${DNAT_CONFIG_FILE}"
  elif [[ -n "${DNAT_RULES:-}" ]]; then
    echo "[entrypoint] loading DNAT rules from environment variable" >&2
    # Parse comma-separated rules from environment variable
    IFS=',' read -ra DNAT_RULES_ARRAY <<< "${DNAT_RULES}"
  fi
  
  # Apply DNAT rules if any were found
  if [[ ${#DNAT_RULES_ARRAY[@]} -gt 0 ]]; then
    echo "[entrypoint] configuring ${#DNAT_RULES_ARRAY[@]} DNAT rule(s)" >&2
    
    # Enable IP forwarding (try multiple methods)
    if echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null; then
      echo "[entrypoint] IP forwarding enabled" >&2
    elif sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1; then
      echo "[entrypoint] IP forwarding enabled via sysctl" >&2
    else
      echo "[entrypoint] ERROR: could not enable IP forwarding!" >&2
      echo "[entrypoint] DNAT functionality requires IP forwarding to be enabled" >&2
      echo "[entrypoint] Please ensure controller has privileged mode or sufficient capabilities" >&2
      exit 1
    fi
    
    # Process each rule
    for rule in "${DNAT_RULES_ARRAY[@]}"; do
      IFS=':' read -r source_ip target_host <<< "$rule"
      if [[ -n "${source_ip}" && -n "${target_host}" ]]; then
        # Resolve target hostname to IP
        target_ip=$(getent hosts "${target_host}" | awk '{ print $1 }' | head -n1)
        
        if [[ -n "${target_ip}" ]]; then
          echo "[entrypoint] setting up DNAT: ${source_ip} -> ${target_host}(${target_ip})" >&2
          
          # DNAT rule for outgoing connections
          iptables -t nat -A OUTPUT -d "${source_ip}" -j DNAT --to-destination "${target_ip}"
          
          # DNAT rule for forwarded packets (if needed)
          iptables -t nat -A PREROUTING -d "${source_ip}" -j DNAT --to-destination "${target_ip}"
          
          # SNAT/MASQUERADE for return traffic
          iptables -t nat -A POSTROUTING -d "${target_ip}" -j MASQUERADE
        else
          echo "[entrypoint] warning: could not resolve ${target_host}, skipping DNAT rule" >&2
        fi
      fi
    done
    
    echo "[entrypoint] DNAT rules configured successfully" >&2
    iptables -t nat -L -n -v >&2
  else
    echo "[entrypoint] no DNAT rules configured" >&2
  fi
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

