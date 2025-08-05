#!/bin/bash
# FINAL KUBELET FIX - Completely disable kubelet config file
set -e

echo "🔧 FINAL KUBELET CONFIG FILE FIX"
echo "================================"

# Stop RKE2 first
systemctl stop rke2-server.service || true

# Create the final RKE2 config that completely disables kubelet config file
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 Configuration for LXC containers - FINAL FIX
server: https://10.14.100.1:9345
token: K10c2b5e5f6ba6b8e6f3e4b8b8b8b8b8b8b8b8b8b8::server:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6

# Explicitly disable kubelet config file (multiple methods)
kubelet-config-file: ""

# Kubelet arguments - COMPLETE SET with explicit config disable
kubelet-arg:
  - "config="
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
  - "anonymous-auth=false"
  - "authentication-token-webhook=true"
  - "authorization-mode=Webhook"
  - "eviction-hard=imagefs.available<5%,nodefs.available<5%"
  - "eviction-minimum-reclaim=imagefs.available=10%,nodefs.available=10%"
  - "healthz-bind-address=127.0.0.1"
  - "read-only-port=0"
  - "tls-cert-file=/var/lib/rancher/rke2/agent/serving-kubelet.crt"
  - "tls-private-key-file=/var/lib/rancher/rke2/agent/serving-kubelet.key"
  - "client-ca-file=/var/lib/rancher/rke2/agent/client-ca.crt"
  - "kubeconfig=/var/lib/rancher/rke2/agent/kubelet.kubeconfig"

# etcd optimizations for containers
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"

# API server optimizations
kube-apiserver-arg:
  - "request-timeout=300s"
EOF

echo "✅ Created final RKE2 config with explicit kubelet config disable"

# Remove any existing kubelet config files that might be interfering
rm -f /var/lib/kubelet/config.yaml
rm -f /etc/kubernetes/kubelet/kubelet-config.json
rm -f /etc/rancher/rke2/kubelet-config.yaml

echo "✅ Removed all potential kubelet config files"

# Ensure /dev/kmsg exists
ln -sf /dev/null /dev/kmsg

echo "✅ Ensured /dev/kmsg exists"

# Start RKE2
echo "Starting RKE2 with final kubelet fix..."
systemctl start rke2-server.service

echo "✅ FINAL KUBELET FIX APPLIED!"
echo "Monitor with: journalctl -u rke2-server.service -f"
echo "This should completely eliminate kubelet config file errors"
