#!/bin/bash
# Final LXC cgroup and runtime fix
# Apply this if kubelet still crashes after Ansible deployment

echo "🔧 Final LXC cgroup and runtime fix"
echo "==================================="

# Stop RKE2 temporarily
systemctl stop rke2-server.service || true
sleep 5

# Check and fix cgroup delegation
echo "1. Fixing cgroup delegation..."
mkdir -p /etc/systemd/system/rke2-server.service.d
cat > /etc/systemd/system/rke2-server.service.d/override.conf << 'EOF'
[Service]
# LXC cgroup fixes
Delegate=yes
TasksMax=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
# Ensure proper cgroup handling
ExecStartPre=-/bin/sh -c 'echo "+cpu +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control || true'
EOF

# Fix kubelet configuration for LXC
echo "2. Creating kubelet config override..."
mkdir -p /var/lib/kubelet
cat > /var/lib/kubelet/config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# Critical LXC fixes
failSwapOn: false
cgroupDriver: systemd
# Container runtime
containerRuntimeEndpoint: unix:///run/k3s/containerd/containerd.sock
# Disable problematic features in LXC
featureGates:
  SCTPSupport: false
  LocalStorageCapacityIsolation: false
# Resource limits for containers
maxPods: 100
podPidsLimit: 2048
# Reduce resource pressure
serializeImagePulls: false
registryPullQPS: 5
registryBurst: 10
# Longer timeouts for LXC
runtimeRequestTimeout: 10m
nodeStatusUpdateFrequency: 30s
EOF

# Create final containerd config
echo "3. Fixing containerd for LXC..."
mkdir -p /var/lib/rancher/rke2/agent/etc/containerd
cat > /var/lib/rancher/rke2/agent/etc/containerd/config.toml << 'EOF'
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  disable_tcp_service = true
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  sandbox_image = "registry.k8s.io/pause:3.9"
  max_container_log_line_size = 16384

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
  Root = "/var/lib/rancher/rke2/agent/containerd"

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/var/lib/rancher/rke2/bin"
  conf_dir = "/var/lib/rancher/rke2/agent/etc/cni/net.d"
EOF

# Reload systemd and restart services
echo "4. Restarting services..."
systemctl daemon-reload
systemctl restart containerd
sleep 5
systemctl start rke2-server.service

echo "✅ Final LXC fixes applied!"
echo "Monitor with: journalctl -u rke2-server.service -f"
