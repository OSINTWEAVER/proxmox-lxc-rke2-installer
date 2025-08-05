#!/bin/bash
# Simple fix: Disable kubelet kernel protection in RKE2 config

echo "🔧 SIMPLE KUBELET FIX FOR LXC"
echo "=============================="

# Stop RKE2
systemctl stop rke2-server.service || true
sleep 3

# Backup current config
cp /etc/rancher/rke2/config.yaml /etc/rancher/rke2/config.yaml.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Create new RKE2 config with kubelet args that work in LXC
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 Configuration for LXC containers
server: https://10.14.100.1:9345
token: K10c2b5e5f6ba6b8e6f3e4b8b8b8b8b8b8b8b8b8b8b8::server:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6

# Kubelet arguments for LXC compatibility
kubelet-arg:
  - "protect-kernel-defaults=false"
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=30s"
  - "make-iptables-util-chains=false"

# etcd optimizations for containers
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"

# API server optimizations
kube-apiserver-arg:
  - "request-timeout=300s"
EOF

echo "✅ Created LXC-compatible RKE2 config"

# Set proper permissions
chmod 600 /etc/rancher/rke2/config.yaml

echo "Starting RKE2..."
systemctl start rke2-server.service

echo "✅ SIMPLE KUBELET FIX APPLIED!"
echo "Monitor with: journalctl -u rke2-server.service -f"
