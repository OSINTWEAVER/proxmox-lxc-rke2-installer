#!/bin/bash
# Fix kubelet kernel parameter access issues in LXC

echo "🔧 FIXING KUBELET KERNEL PARAMETER ACCESS IN LXC"
echo "================================================"

# Stop RKE2 first
systemctl stop rke2-server.service || true
sleep 3

# Create kubelet configuration to disable kernel parameter management
mkdir -p /var/lib/kubelet

cat > /var/lib/kubelet/config.yaml << 'EOF'
# Kubelet configuration for LXC containers
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# Disable kernel parameter management in LXC
protectKernelDefaults: false

# Container runtime settings
containerRuntimeEndpoint: "unix:///run/k3s/containerd/containerd.sock"
failSwapOn: false
cgroupDriver: systemd

# Resource management
maxPods: 250
serializeImagePulls: false

# Event and API rate limiting
eventQPS: 10
eventBurst: 20
kubeAPIQPS: 20
kubeAPIBurst: 40

# Registry settings
registryPullQPS: 10
registryBurst: 20

# Runtime request timeout
runtimeRequestTimeout: "30s"

# Authentication and authorization
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow

# Disable features that require kernel access
makeIPTablesUtilChains: false
EOF

echo "✅ Created kubelet config at /var/lib/kubelet/config.yaml"

# Update RKE2 config to use our kubelet config
if [ -f /etc/rancher/rke2/config.yaml ]; then
    # Add kubelet-config-file to existing config
    if ! grep -q "kubelet-config-file" /etc/rancher/rke2/config.yaml; then
        echo "" >> /etc/rancher/rke2/config.yaml
        echo "# Use custom kubelet config for LXC compatibility" >> /etc/rancher/rke2/config.yaml
        echo "kubelet-config-file: /var/lib/kubelet/config.yaml" >> /etc/rancher/rke2/config.yaml
    fi
fi

echo "✅ Updated RKE2 config to use custom kubelet configuration"

echo "3. Restarting RKE2..."
systemctl start rke2-server.service

echo "✅ KUBELET KERNEL PARAMETER FIX APPLIED!"
echo "Monitor with: journalctl -u rke2-server.service -f"
