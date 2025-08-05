#!/bin/bash
# FINAL SIMPLE APPROACH - Just modify kubelet args to avoid the problematic ones
set -e

echo "🎯 FINAL SIMPLE APPROACH - Config-based fix"
echo "=========================================="

# Stop everything
echo "1. Stopping services..."
systemctl stop rke2-server || true
sleep 3

# Clean up only what's necessary
echo "2. Cleaning up..."
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /etc/systemd/system/rke2-server.service.d

echo "3. Installing RKE2..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "4. Creating config that explicitly avoids problematic kubelet args..."
mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml << 'EOF'
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# CRITICAL: Override the problematic kubelet args with safe values
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "protect-kernel-defaults=false"
  - "enforce-node-allocatable="
  - "system-reserved="
  - "kube-reserved="
  - "eviction-hard="
  - "eviction-soft="
  - "eviction-minimum-reclaim="
EOF

echo "5. Creating kubelet config that prevents resource management..."
cat > /etc/rancher/rke2/kubelet-config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# Container runtime
containerRuntimeEndpoint: "unix:///run/k3s/containerd/containerd.sock"
runtimeRequestTimeout: "15m0s"

# Basic auth
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook

# DNS
clusterDNS:
  - "10.43.0.10"
clusterDomain: "cluster.local"

# Cgroup
cgroupDriver: "systemd"
failSwapOn: false
protectKernelDefaults: false

# CRITICAL: Completely disable resource management
enforceNodeAllocatable: []
systemReserved: {}
kubeReserved: {}
evictionHard: {}
evictionSoft: {}
evictionMinimumReclaim: {}
EOF

echo "6. Basic LXC networking setup..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true

# /dev/kmsg workaround
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "7. Starting RKE2 with config-based fix..."
systemctl daemon-reload
systemctl enable rke2-server
systemctl start rke2-server

echo ""
echo "✅ CONFIG-BASED FIX APPLIED!"
echo "============================"
echo "This approach uses kubelet-arg in the config to override problematic arguments."
echo "No wrapper scripts - just pure configuration override."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
echo ""
echo "Wait 2-3 minutes for the cluster to fully initialize."
