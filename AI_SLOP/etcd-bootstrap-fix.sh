#!/bin/bash
# ETCD BOOTSTRAP FIX for RKE2 in LXC
# This script will create a minimal etcd bootstrap configuration

set -e

echo "🔄 APPLYING ETCD BOOTSTRAP FIX FOR RKE2 IN LXC"
echo "=============================================="

# Stop RKE2 server
systemctl stop rke2-server.service || true
sleep 3

# Create the etcd bootstrap directory
mkdir -p /var/lib/rancher/rke2/server/db/etcd
mkdir -p /var/lib/rancher/rke2/server/manifests

# Create a basic etcd configuration
cat > /var/lib/rancher/rke2/server/db/etcd/config << 'EOF'
name: os-env-cp-1
data-dir: /var/lib/rancher/rke2/server/db/etcd
initial-cluster: os-env-cp-1=https://10.14.100.1:2380
initial-advertise-peer-urls: https://10.14.100.1:2380
advertise-client-urls: https://10.14.100.1:2379
listen-client-urls: https://0.0.0.0:2379
listen-peer-urls: https://0.0.0.0:2380
initial-cluster-token: etcd-cluster
initial-cluster-state: new
EOF

# Start RKE2 server
systemctl start rke2-server.service

echo "✅ ETCD BOOTSTRAP FIX APPLIED!"
echo "Wait for RKE2 server to initialize..."
echo "Check status with: journalctl -u rke2-server.service -f"
