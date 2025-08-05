#!/bin/bash
# Advanced LXC Container Runtime Diagnosis & Fix
# Run this on the control plane to debug the kubelet crashes

set -e

echo "🔍 Advanced LXC Container Runtime Diagnosis"
echo "==========================================="

# Check cgroup v2 configuration
echo "1. Checking cgroup configuration..."
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "✅ cgroup v2 detected"
    echo "Available controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
else
    echo "❌ cgroup v2 not available - this may cause issues"
fi

# Check container runtime configuration
echo "2. Checking container runtime..."
if [ -f /var/lib/rancher/rke2/agent/etc/containerd/config.toml ]; then
    echo "✅ Containerd config exists"
    # Check for cgroup configuration
    if grep -q "SystemdCgroup = true" /var/lib/rancher/rke2/agent/etc/containerd/config.toml; then
        echo "✅ SystemdCgroup enabled"
    else
        echo "❌ SystemdCgroup not enabled - this can cause kubelet crashes"
    fi
else
    echo "❌ Containerd config missing"
fi

# Check kubelet logs specifically
echo "3. Checking kubelet specific issues..."
journalctl -u rke2-server.service --since "5 minutes ago" | grep -i kubelet | tail -10

# Check if etcd is trying to start as a static pod
echo "4. Checking etcd static pod status..."
if [ -d /var/lib/rancher/rke2/server/manifests ]; then
    echo "Static pod manifests directory exists"
    ls -la /var/lib/rancher/rke2/server/manifests/ || echo "Empty or no access"
fi

# Check for etcd data directory
echo "5. Checking etcd data..."
if [ -d /var/lib/rancher/rke2/server/db/etcd ]; then
    echo "✅ etcd data directory exists"
    ls -la /var/lib/rancher/rke2/server/db/etcd/ | head -5
else
    echo "❌ etcd data directory missing"
fi

# Check actual running processes
echo "6. Checking running Kubernetes processes..."
ps aux | grep -E "(kubelet|etcd|kube-)" | grep -v grep || echo "No Kubernetes processes found"

echo "7. Diagnosis complete - preparing fixes..."

# Apply container runtime fixes
echo "🔧 Applying container runtime fixes..."

# Fix containerd configuration for LXC
if [ -f /var/lib/rancher/rke2/agent/etc/containerd/config.toml ]; then
    echo "Backing up containerd config..."
    cp /var/lib/rancher/rke2/agent/etc/containerd/config.toml /var/lib/rancher/rke2/agent/etc/containerd/config.toml.backup
    
    # Ensure systemd cgroup is enabled
    if ! grep -q "SystemdCgroup = true" /var/lib/rancher/rke2/agent/etc/containerd/config.toml; then
        echo "Adding SystemdCgroup configuration..."
        sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]/a \ \ \ \ SystemdCgroup = true' /var/lib/rancher/rke2/agent/etc/containerd/config.toml
    fi
fi

# Restart containerd to apply changes
echo "Restarting containerd..."
systemctl restart containerd

# Give containerd time to start
sleep 5

# Restart RKE2 server
echo "Restarting RKE2 server..."
systemctl restart rke2-server.service

echo "✅ Container runtime fixes applied!"
echo "Monitor with: journalctl -u rke2-server.service -f"
