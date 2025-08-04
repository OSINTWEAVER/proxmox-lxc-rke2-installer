#!/bin/bash
# FINAL FIX: Remove kubelet config file and use only RKE2 kubelet args

echo "🔧 FINAL KUBELET FIX FOR LXC"
echo "============================"

# Stop RKE2
systemctl stop rke2-server.service || true
sleep 3

# Remove the problematic kubelet config file that was being ignored
rm -f /var/lib/kubelet/config.yaml

# Backup current config
cp /etc/rancher/rke2/config.yaml /etc/rancher/rke2/config.yaml.backup.final.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Create new RKE2 config using ONLY kubelet args (no external config file)
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 Configuration for LXC containers
server: https://10.14.100.1:9345
token: K10c2b5e5f6ba6b8e6f3e4b8b8b8b8b8b8b8b8b8b8b8::server:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6

# Kubelet arguments for LXC compatibility - these WILL work
kubelet-arg:
  - "protect-kernel-defaults=false"
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=30s"
  - "make-iptables-util-chains=false"
  - "max-pods=250"
  - "serialize-image-pulls=false"
  - "registry-qps=10"
  - "registry-burst=20"
  - "event-qps=10"
  - "event-burst=20"
  - "kube-api-qps=20"
  - "kube-api-burst=40"

# etcd optimizations for containers
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"

# API server optimizations
kube-apiserver-arg:
  - "request-timeout=300s"
EOF

echo "✅ Created corrected RKE2 config using ONLY kubelet arguments"

# Set proper permissions
chmod 600 /etc/rancher/rke2/config.yaml

# Ensure /dev/kmsg exists
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "Starting RKE2..."
systemctl start rke2-server.service

echo "✅ FINAL KUBELET FIX APPLIED!"
echo "Kubelet should now start without kernel parameter errors"
echo "Monitor with: journalctl -u rke2-server.service -f"
