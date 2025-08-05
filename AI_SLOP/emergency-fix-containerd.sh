#!/bin/bash

# Emergency fix for duplicate containerd config causing startup failure
# This is a one-time fix to clean up the malformed TOML file

echo "🚨 Emergency: Fixing duplicate containerd configuration..."

# Check if we're in LXC
if ! grep -qa container=lxc /proc/1/environ; then
    echo "❌ This script is for LXC containers only"
    exit 1
fi

# Stop RKE2 if running
systemctl stop rke2-server 2>/dev/null || true

# Backup the broken config
cp /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl.broken

# Create a clean containerd config
cat > /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl << 'EOF'
# LXC-optimized containerd configuration
# This template modifies RKE2's embedded containerd to use cgroupfs instead of systemd cgroups
# and disables AppArmor to resolve compatibility issues in LXC containers

version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    # Disable AppArmor in LXC containers to prevent policy conflicts
    disable_apparmor = true
    
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            # Disable systemd cgroup management to fix LXC compatibility
            SystemdCgroup = false
            # Use cgroupfs driver instead
            BinaryName = "runc"
        
        # NVIDIA runtime configuration for GPU support (if needed)
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "/usr/bin/nvidia-container-runtime"
            SystemdCgroup = false
    
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
    
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
EOF

echo "✅ Cleaned up duplicate containerd configuration"
echo "🔄 Now ready for Ansible redeployment"
echo ""
echo "Next: Run your Ansible playbook to complete the fix"
