#!/bin/bash
# ULTIMATE FIX: Disable kubelet config file completely in RKE2

echo "🔧 ULTIMATE KUBELET FIX FOR LXC"
echo "==============================="

# Stop RKE2
systemctl stop rke2-server.service || true
sleep 3

# Remove any kubelet config file
rm -f /var/lib/kubelet/config.yaml

# Backup current config
cp /etc/rancher/rke2/config.yaml /etc/rancher/rke2/config.yaml.backup.ultimate.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Create RKE2 config that explicitly disables kubelet config file
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 Configuration for LXC containers - NO kubelet config file
server: https://10.14.100.1:9345
token: K10c2b5e5f6ba6b8e6f3e4b8b8b8b8b8b8b8b8b8b8b8::server:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6

# Explicitly disable kubelet config file
kubelet-config-file: ""

# Kubelet arguments for LXC compatibility - COMPLETE SET
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

echo "✅ Created RKE2 config with explicitly disabled kubelet config file"

# Set proper permissions
chmod 600 /etc/rancher/rke2/config.yaml

# Ensure /dev/kmsg exists
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "Starting RKE2..."
systemctl start rke2-server.service

echo "✅ ULTIMATE KUBELET FIX APPLIED!"
echo "RKE2 will now use ONLY kubelet arguments, no config file"
echo "Monitor with: journalctl -u rke2-server.service -f"
