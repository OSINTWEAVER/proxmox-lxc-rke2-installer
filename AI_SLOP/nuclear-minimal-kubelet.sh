#!/bin/bash
# ABSOLUTE NUCLEAR FIX for RKE2 kubelet in LXC containers
# This script will create a minimal, stripped-down kubelet config that avoids all resource management
# and works around the "strconv.Atoi: parsing "": invalid syntax" error

set -e

# Stop RKE2 server
systemctl stop rke2-server.service

# Remove any potentially conflicting files
rm -f /var/lib/kubelet/config.yaml
rm -f /etc/systemd/system/rke2-server.service.d/10-lxc-kubelet.conf

# Create super-minimal kubelet config that avoids all resource management
cat > /etc/rancher/rke2/kubelet-config.yaml << 'EOF'
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# Minimal container runtime config
containerRuntimeEndpoint: "unix:///run/k3s/containerd/containerd.sock"

# Absolute minimum settings - avoid any resource management
cgroupDriver: systemd
cgroupsPerQOS: false
enforceNodeAllocatable: []
protectKernelDefaults: false

# Completely disable all resource reservations
kubeReserved: {}
systemReserved: {}

# Basic networking
clusterDNS:
  - "10.43.0.10"
clusterDomain: "cluster.local"
EOF

# Update RKE2 config to use the minimal config and avoid conflicting args
cat > /etc/rancher/rke2/config.yaml << 'EOF'
token: youmomma-atnowfrin12
data-dir: /var/lib/rancher/rke2
# Use containerd with Docker runtime configuration for LXC containers
# RKE2 uses containerd as CRI, which can use Docker as the runtime
cni: flannel
tls-san:
  - cluster.local
  - 10.14.100.1
node-taint:
  - CriticalAddonsOnly=true:NoExecute
disable: ['rke2-canal', 'rke2-ingress-nginx']
snapshotter: overlayfs
node-name: 10.14.100.1
# Minimal kubelet args - use config file only, no command line overrides
kubelet-arg:
  # Minimal kubelet config with no resource management
  - "config=/etc/rancher/rke2/kubelet-config.yaml"
  # Override any RKE2 defaults for resource management
  - "enforce-node-allocatable="
  - "kube-reserved="
  - "system-reserved="
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
# LXC-specific etcd configuration for better stability
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"
  - "quota-backend-bytes=8589934592"
EOF

# Create systemd override that completely disables resource management
mkdir -p /etc/systemd/system/rke2-server.service.d
cat > /etc/systemd/system/rke2-server.service.d/99-nuclear-fix.conf << 'EOF'
[Service]
# Force RKE2 to completely ignore resource management
Environment="KUBELET_DISABLE_RESOURCE_MANAGEMENT=true"
Environment="CONTAINERD_DISABLE_CGROUPS=true"
# Add essential capabilities
Delegate=yes
# Remove resource limits
TasksMax=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
# Avoid cgroup issues in LXC
ExecStartPre=-/bin/sh -c 'echo "+cpu +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control || true'
ExecStartPre=-/bin/sh -c 'rm -f /var/lib/kubelet/config.yaml'
ExecStartPre=-/bin/sh -c 'rm -f /var/lib/kubelet/*.json'
EOF

# Reload systemd
systemctl daemon-reload

# Create /dev/kmsg
ln -sf /dev/null /dev/kmsg

# Start RKE2 server
systemctl start rke2-server.service

echo "NUCLEAR FIX APPLIED!"
echo "====================="
echo "- Created minimal kubelet-config.yaml"
echo "- Updated RKE2 config.yaml"
echo "- Created systemd override to disable resource management"
echo "- Created /dev/kmsg -> /dev/null symlink"
echo "- Restarted RKE2 server"
echo ""
echo "Check status with: journalctl -u rke2-server.service -f"
