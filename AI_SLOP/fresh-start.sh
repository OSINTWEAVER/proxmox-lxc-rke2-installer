#!/bin/bash
# FRESH START: Ultra-simple RKE2 installation from zero
set -e

echo "🚀 FRESH START - Ultra-simple RKE2 installation"
echo "=============================================="

echo "1. Verifying clean environment..."
if systemctl is-active rke2-server >/dev/null 2>&1; then
    echo "❌ RKE2 is still running! Run nuclear-cleanup.sh first!"
    exit 1
fi

if [ -d "/var/lib/rancher/rke2" ]; then
    echo "❌ RKE2 directory still exists! Run nuclear-cleanup.sh first!"
    exit 1
fi

echo "✅ Environment is clean"

echo "2. Installing RKE2..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "3. Creating ultra-minimal config..."
mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml << 'EOF'
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# Override kubelet args to prevent resource management issues
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "protect-kernel-defaults=false"
  - "enforce-node-allocatable="
  - "kube-reserved="
  - "system-reserved="
EOF

echo "4. Basic LXC networking setup..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 || true

# LXC /dev/kmsg workaround
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "5. Starting RKE2 with zero modifications..."
systemctl daemon-reload
systemctl enable rke2-server
systemctl start rke2-server

echo ""
echo "🚀 FRESH RKE2 INSTALLATION STARTED!"
echo "=================================="
echo "This is a completely clean installation with minimal config."
echo "The kubelet args override the problematic resource management settings."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
echo "Check status: systemctl status rke2-server"
echo ""
echo "Wait 3-5 minutes for full startup, then test with:"
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
echo "/var/lib/rancher/rke2/bin/kubectl get nodes"
