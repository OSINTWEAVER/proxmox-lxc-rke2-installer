#!/bin/bash
# Deploy SQLite-based RKE2 to LXC container
# Usage: ./deploy-sqlite-rke2.sh <user@host> [password]

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <user@host> [password]"
  echo "Example: $0 root@10.14.100.1"
  exit 1
fi

TARGET="$1"
PASSWORD="$2"

echo "🚀 Deploying SQLite-based RKE2 fix to $TARGET"
echo "=============================================="

# Helper function to run commands with or without password
run_ssh_command() {
  local host="$1"
  local cmd="$2"
  
  if [ -n "$PASSWORD" ]; then
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$host" "$cmd"
  else
    ssh -o StrictHostKeyChecking=no "$host" "$cmd"
  fi
}

# Helper function to copy files with or without password
copy_file() {
  local src="$1"
  local host="$2"
  local dest="$3"
  
  if [ -n "$PASSWORD" ]; then
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$src" "$host":"$dest"
  else
    scp -o StrictHostKeyChecking=no "$src" "$host":"$dest"
  fi
}

# 1. Copy the nuclear script to the target
echo "1. Copying nuclear-minimal-rke2.sh to target..."
copy_file "development_fix_scripts/nuclear-minimal-rke2.sh" "$TARGET" "/tmp/nuclear-minimal-rke2.sh"

# 2. Copy diagnostic script to the target
echo "2. Copying diagnostic script to target..."
copy_file "diagnostic_scripts/container-runtime-diagnostic.sh" "$TARGET" "/tmp/container-runtime-diagnostic.sh"

# 3. Make scripts executable
echo "3. Making scripts executable..."
run_ssh_command "$TARGET" "chmod +x /tmp/nuclear-minimal-rke2.sh /tmp/container-runtime-diagnostic.sh"

# 4. Run diagnostic before changes
echo "4. Running pre-change diagnostics..."
run_ssh_command "$TARGET" "/tmp/container-runtime-diagnostic.sh > /tmp/pre-change-diagnostics.log"

# 5. Apply nuclear script
echo "5. Applying SQLite-based RKE2 fix..."
run_ssh_command "$TARGET" "/tmp/nuclear-minimal-rke2.sh"

# 6. Run diagnostic after changes
echo "6. Running post-change diagnostics..."
run_ssh_command "$TARGET" "sleep 30 && /tmp/container-runtime-diagnostic.sh > /tmp/post-change-diagnostics.log"

# 7. Check the status
echo "7. Checking RKE2 status..."
run_ssh_command "$TARGET" "journalctl -u rke2-minimal -n 50 --no-pager"

echo ""
echo "✅ DEPLOYMENT COMPLETED!"
echo "To check status on the target, run:"
echo "  ssh $TARGET journalctl -u rke2-minimal -f"
echo "To verify nodes are running, execute on the target:"
echo "  ssh $TARGET \"export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl get nodes\""
echo ""
echo "Diagnostic logs are available on the target at:"
echo "  /tmp/pre-change-diagnostics.log  - Before changes"
echo "  /tmp/post-change-diagnostics.log - After changes"
