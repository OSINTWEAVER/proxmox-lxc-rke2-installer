#!/bin/bash
# Proxmox Host Preparation Script for LXC Kubernetes Deployment
# Run this script on the Proxmox host BEFORE deploying Kubernetes

set -e

echo "=== Proxmox Host Preparation for LXC Kubernetes ==="
echo "This script configures the Proxmox host for LXC-based Kubernetes deployment"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root on the Proxmox host"
   exit 1
fi

echo "📋 Step 1: Loading required kernel modules..."

# Load essential kernel modules
MODULES=(
    "br_netfilter"
    "overlay" 
    "ip_tables"
    "ip6_tables"
    "nf_nat"
    "xt_conntrack"
    "nf_conntrack"
)

for module in "${MODULES[@]}"; do
    if modprobe "$module" 2>/dev/null; then
        echo "✅ Loaded: $module"
    else
        echo "⚠️  Warning: Could not load $module (may already be loaded)"
    fi
done

echo
echo "📋 Step 2: Making kernel modules persistent..."

# Create persistent module loading
cat > /etc/modules-load.d/k8s-lxc.conf << EOF
# Kernel modules required for Kubernetes in LXC containers
br_netfilter
overlay
ip_tables
ip6_tables
nf_nat
xt_conntrack
nf_conntrack
EOF

echo "✅ Created /etc/modules-load.d/k8s-lxc.conf"

echo
echo "📋 Step 3: Configuring network bridge settings..."

# Configure bridge netfilter settings
cat > /etc/sysctl.d/k8s-bridge.conf << EOF
# Bridge netfilter settings for Kubernetes
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-arptables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Apply sysctl settings
sysctl --system >/dev/null 2>&1
echo "✅ Applied bridge netfilter configuration"

echo
echo "📋 Step 4: Verifying kernel module status..."

# Verify modules are loaded
echo "Loaded kernel modules:"
for module in "${MODULES[@]}"; do
    if lsmod | grep -q "^$module"; then
        echo "  ✅ $module: LOADED"
    else
        echo "  ❌ $module: NOT LOADED"
    fi
done

echo
echo "📋 Step 5: Verifying bridge netfilter configuration..."

# Check bridge netfilter settings
if [[ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]]; then
    iptables_val=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || echo "0")
    ip6tables_val=$(cat /proc/sys/net/bridge/bridge-nf-call-ip6tables 2>/dev/null || echo "0")
    
    if [[ "$iptables_val" == "1" && "$ip6tables_val" == "1" ]]; then
        echo "✅ Bridge netfilter: ENABLED"
    else
        echo "❌ Bridge netfilter: DISABLED (iptables: $iptables_val, ip6tables: $ip6tables_val)"
    fi
else
    echo "❌ Bridge netfilter: NOT AVAILABLE (br_netfilter module not loaded)"
fi

echo
echo "🔧 NEXT STEPS:"
echo "1. Configure your LXC containers as PRIVILEGED"
echo "2. See LXC_DEPLOYMENT_CRITICAL_FIXES.md for complete container configuration"
echo "3. Run your Kubernetes deployment: ./deploy.sh hosts.ini"

echo
echo "📄 Example LXC Container Configuration:"
echo "Add these lines to /etc/pve/lxc/{CONTAINER_ID}.conf:"
echo
cat << 'EOF'
# CRITICAL: Privileged mode for Kubernetes
privileged: 1

# CRITICAL: Container features (set during creation with --features)
# Use: --features fuse=1,keyctl=1,nesting=1
# DO NOT manually add lxc.apparmor.profile when using nesting=1

# CRITICAL: Device and mount access
lxc.cgroup.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: cgroup:rw proc:rw sys:rw
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,optional,create=file
lxc.mount.entry: /lib/modules lib/modules none bind,ro,optional
lxc.seccomp.profile:
EOF

echo
echo "✅ Proxmox host preparation complete!"
echo "🔄 Remember to restart your LXC containers after updating their configuration"
