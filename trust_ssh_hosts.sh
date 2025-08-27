#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./proxmox/scripts/trust_ssh_hosts.sh proxmox [--user root] [--key-path ~/.ssh/id_ed25519.pub] 10.0.10.8 10.0.10.1 10.0.10.2
#   ./proxmox/scripts/trust_ssh_hosts.sh nodes   [--user adm4n] [--key-path ~/.ssh/id_ed25519.pub] 10.14.100.1 10.14.100.2 10.14.100.3
# Prompts once for password and adds SSH keys to known_hosts; also pre-seeds SSH auth via sshpass. WSL/Linux only.

MODE=${1:-}
shift || true

# Optional flags: --user and --key-path
TARGET_USER=""
KEY_PATH=""
if [[ "${1:-}" == "--user" ]]; then
  shift || true
  TARGET_USER=${1:-}
  shift || true
fi

if [[ "${1:-}" == "--key-path" ]]; then
  shift || true
  KEY_PATH=${1:-}
  shift || true
fi

HOSTS=("$@")

if [[ -z "$MODE" || ${#HOSTS[@]} -eq 0 ]]; then
  echo "Usage: $0 <proxmox|nodes> [--user <username>] <host1> [host2 ...]"
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "Installing sshpass (requires sudo)..."
  sudo apt-get update -y && sudo apt-get install -y sshpass
fi

if [[ -z "$TARGET_USER" ]]; then
  if [[ "$MODE" == "proxmox" ]]; then
    TARGET_USER="root"
  else
    TARGET_USER="adm4n"
  fi
fi

read -s -p "Enter SSH password for ${MODE} targets (user ${TARGET_USER}): " SSH_PASS
echo

# Determine which public key to use (WSL/Linux only)
if [[ -z "$KEY_PATH" ]]; then
  # Ensure ~/.ssh exists
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "Generating new SSH keypair at ~/.ssh/id_ed25519 ..."
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" >/dev/null
  fi
  KEY_PATH="$HOME/.ssh/id_ed25519.pub"
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "ERROR: Key path $KEY_PATH not found. Use --key-path to specify a valid public key."
  exit 2
fi

for h in "${HOSTS[@]}"; do
  echo "Trusting host: $h"
  # Always remove existing entries for this host (handles IP reuse after VM recreation)
  echo "  Removing any existing SSH entries for $h..."
  ssh-keygen -R "$h" >/dev/null 2>&1 || true
  
  # Also remove by hostname if it exists in known_hosts 
  if [[ -f "$HOME/.ssh/known_hosts" ]]; then
    # Remove any lines containing this IP (handles different key formats)
    sed -i "/^$h\|,$h\|^.*$h /d" "$HOME/.ssh/known_hosts" 2>/dev/null || true
  fi
  
  # Fetch and trust fresh host key
  echo "  Adding fresh SSH host key for $h..."
  ssh-keyscan -H "$h" >> ~/.ssh/known_hosts 2>/dev/null || true
  chmod 600 ~/.ssh/known_hosts

  # Test login and push our public key (password-based initial auth)
  echo "Pushing SSH public key to $h for user ${TARGET_USER} ..."
  ATTEMPTS=0; MAX_ATTEMPTS=3; OK=0
  while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    if sshpass -p "$SSH_PASS" ssh -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -o StrictHostKeyChecking=no ${TARGET_USER}@"$h" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < "$KEY_PATH"; then
      OK=1; break
    fi
    ATTEMPTS=$((ATTEMPTS+1))
    echo "Attempt $ATTEMPTS/$MAX_ATTEMPTS failed to push key to $h; retrying..."
    sleep 1
  done
  if [[ $OK -ne 1 ]]; then
    echo "Failed to push key to $h after $MAX_ATTEMPTS attempts."
  fi

  # Simple connectivity check
  if ! ssh -o StrictHostKeyChecking=no ${TARGET_USER}@"$h" "echo 'SSH OK on $(hostname)'"; then
    echo "Hint: If authentication keeps failing, on the Proxmox host check /etc/ssh/sshd_config for:\n  PermitRootLogin yes (if using root)\n  PasswordAuthentication yes (only for the initial push)\nThen: systemctl restart ssh\nIf using 2FA for root, temporarily disable it or use a non-root user with --user."
  fi
done

echo "All ${MODE} hosts processed. Passwordless access should now work if keys were pushed."
