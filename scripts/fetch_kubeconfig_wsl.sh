#!/usr/bin/env bash
# fetch_kubeconfig_wsl.sh - RKE2-aware kubeconfig fetch with proper patching
# Usage: fetch_kubeconfig_wsl.sh <inventory-file>

set -euo pipefail

inventory_file="${1:-}"
if [ -z "$inventory_file" ]; then
  echo "Usage: $0 <inventory-file>" >&2
  exit 2
fi

if [ ! -f "$inventory_file" ]; then
  echo "Inventory file not found: $inventory_file" >&2
  exit 3
fi

# Get current script directory for repo-relative operations
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# Extract inventory base name (e.g., "hosts-iris.ini" -> "iris")
inventory_basename=$(basename "$inventory_file" .ini)
inventory_name=${inventory_basename#hosts-}

# Create kubeconfig directory structure in repo (gitignored)
kubeconfig_dir="$repo_root/kubeconfig/$inventory_name"
mkdir -p "$kubeconfig_dir"

echo "🔧 Processing kubeconfig in: $kubeconfig_dir"

# Get control-plane IP from rke2_api_ip in inventory
CP_IP=$(awk -F= '/^rke2_api_ip/{gsub(/[ \t\r]/, "", $2); print $2}' "$inventory_file")
if [ -z "$CP_IP" ]; then
  # Fallback to first rke2_servers host
  CP_IP=$(awk '/^\[rke2_servers\]/{getline; while(getline && !/^\[/) {if(NF && !/^#/) {print $1; break}}}' "$inventory_file")
fi

if [ -z "$CP_IP" ]; then
  echo "❌ Could not determine control-plane IP from inventory" >&2
  exit 4
fi

# Get remote user from inventory
remote_user=$(awk -F= '/^cluster_admin_user/{gsub(/[ \t\r"]/, "", $2); print $2}' "$inventory_file")
if [ -z "$remote_user" ]; then
  remote_user=$(awk '/^\[rke2_servers\]/{getline; while(getline && !/^\[/) {if(/ansible_user=/) {sub(/.*ansible_user=/, ""); sub(/[ \t].*/, ""); print; break}}}' "$inventory_file")
fi
remote_user="${remote_user:-$USER}"

echo "🎯 Target: $remote_user@$CP_IP"

# SSH options
ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# Step 1: Fetch kubeconfig to kubeconfig directory
temp_kubeconfig="$kubeconfig_dir/config"
echo "📥 Fetching kubeconfig from $CP_IP..."

if ssh $ssh_opts "$remote_user@$CP_IP" "sudo cat /etc/rancher/rke2/rke2.yaml" > "$temp_kubeconfig" 2>/dev/null; then
  echo "✅ Fetched system kubeconfig"
else
  echo "⚠️  System kubeconfig unavailable, trying user config..."
  if scp $ssh_opts "$remote_user@$CP_IP:~/.kube/config" "$temp_kubeconfig" 2>/dev/null; then
    echo "✅ Fetched user kubeconfig"
  else
    echo "❌ Failed to fetch kubeconfig from $CP_IP" >&2
    exit 5
  fi
fi

# Step 2: Show original server entries
echo "📋 Original server entries:"
grep -n "server:" "$temp_kubeconfig" || echo "  (none found)"

# Step 3: Patch the kubeconfig in kubeconfig directory
echo "🔧 Patching server entries to use $CP_IP..."

# Create backup in kubeconfig dir
cp "$temp_kubeconfig" "$temp_kubeconfig.orig"

# Robust patching using sed with different approaches
sed -i.bak "s|server: https://127\.0\.0\.1:|server: https://$CP_IP:|g" "$temp_kubeconfig"
sed -i "s|server: https://localhost:|server: https://$CP_IP:|g" "$temp_kubeconfig"

# Additional robust replacement for any remaining localhost references
sed -i "s|https://127\.0\.0\.1:6443|https://$CP_IP:6443|g" "$temp_kubeconfig"
sed -i "s|https://localhost:6443|https://$CP_IP:6443|g" "$temp_kubeconfig"

# Verify patching worked
echo "📋 Patched server entries:"
grep -n "server:" "$temp_kubeconfig" || echo "  (none found)"

# Check if patching was successful
if grep -q "127\.0\.0\.1\|localhost" "$temp_kubeconfig"; then
  echo "⚠️  Warning: Some localhost references may remain"
  echo "🔍 Remaining localhost references:"
  grep -n "127\.0\.0\.1\|localhost" "$temp_kubeconfig" || true
else
  echo "✅ All localhost references successfully patched"
fi

# Step 4: Deploy to WSL location
wsl_kube_dir="$HOME/.kube"
wsl_kube_file="$wsl_kube_dir/config"
mkdir -p "$wsl_kube_dir"

echo "📦 Deploying to WSL: $wsl_kube_file"
cp "$temp_kubeconfig" "$wsl_kube_file"
chmod 600 "$wsl_kube_file"

# Step 5: Deploy to Windows location for kubectl
# Try multiple approaches to find Windows user directory
windows_kube_file=""
if [ -d "/mnt/c/Users/$USER" ]; then
  windows_kube_dir="/mnt/c/Users/$USER/.kube"
  windows_kube_file="$windows_kube_dir/config"
elif [ -d "/mnt/c/Users/$LOGNAME" ]; then
  windows_kube_dir="/mnt/c/Users/$LOGNAME/.kube"
  windows_kube_file="$windows_kube_dir/config"
else
  # Try to find any user directory that's not Default, Public, etc
  potential_user=$(ls /mnt/c/Users/ 2>/dev/null | grep -v -E '^(Default|Public|All Users|Default User)$' | head -1)
  if [ -n "$potential_user" ] && [ -d "/mnt/c/Users/$potential_user" ]; then
    windows_kube_dir="/mnt/c/Users/$potential_user/.kube"
    windows_kube_file="$windows_kube_dir/config"
    echo "ℹ️  Using Windows user: $potential_user"
  fi
fi

if [ -n "$windows_kube_file" ]; then
  mkdir -p "$windows_kube_dir"
  echo "📦 Deploying to Windows: $windows_kube_file"
  cp "$temp_kubeconfig" "$windows_kube_file"
  chmod 600 "$windows_kube_file"
  echo "✅ Windows kubeconfig deployed"
else
  echo "⚠️  Could not determine Windows user directory"
  echo "ℹ️  Available users in /mnt/c/Users/: $(ls /mnt/c/Users/ 2>/dev/null | tr '\n' ' ')"
  echo "ℹ️  Manual copy: cp $temp_kubeconfig /mnt/c/Users/YOUR_USERNAME/.kube/config"
fi

# Step 6: Persist KUBECONFIG in WSL
profile_file="$HOME/.profile"
export_line="export KUBECONFIG=\"$wsl_kube_file\""

if ! grep -Fq "$export_line" "$profile_file" 2>/dev/null; then
  echo "🔗 Adding KUBECONFIG to $profile_file"
  cat >> "$profile_file" << EOF

# Set KUBECONFIG for kubectl (added by fetch_kubeconfig_wsl.sh)
$export_line
EOF
else
  echo "ℹ️  KUBECONFIG already configured in $profile_file"
fi

# Step 7: Test kubectl connectivity
echo ""
echo "🧪 Testing kubectl connectivity..."

export KUBECONFIG="$wsl_kube_file"

if command -v kubectl >/dev/null 2>&1; then
  echo "📋 kubectl version:"
  kubectl version --client --short 2>/dev/null || true
  
  echo "🌐 Testing cluster connectivity..."
  if kubectl get nodes --request-timeout=5s 2>/dev/null; then
    echo "✅ kubectl connectivity successful!"
  else
    echo "❌ kubectl connectivity failed"
    echo "🔍 Current server in kubeconfig:"
    grep "server:" "$wsl_kube_file" || true
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   1. Verify RKE2 API is accessible from WSL: nc -zv $CP_IP 6443"
    echo "   2. Check if RKE2 is running: ssh $remote_user@$CP_IP 'sudo systemctl status rke2-server'"
    echo "   3. Manual test: ssh $remote_user@$CP_IP 'sudo kubectl get nodes'"
  fi
else
  echo "⚠️  kubectl not found - install with:"
  echo "   curl -LO https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl"
  echo "   chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
fi

echo ""
echo "🎉 Complete! Kubeconfig deployed to:"
echo "   WSL: $wsl_kube_file"
if [ -n "$windows_kube_file" ]; then
  echo "   Windows: $windows_kube_file"
fi
echo "   Repo backup: $temp_kubeconfig.orig"
echo "   Cluster: $inventory_name ($CP_IP)"
echo ""
echo "🔄 Run: source $profile_file (or open new shell)"
