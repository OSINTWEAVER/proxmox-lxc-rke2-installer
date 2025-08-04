#!/bin/bash
# Quick fix for invalid feature gates causing kubelet crashes

echo "🔧 FIXING INVALID FEATURE GATES"
echo "==============================="

# Stop RKE2
systemctl stop rke2-server.service || true
sleep 3

# Fix the RKE2 config by removing invalid feature gates
echo "1. Fixing RKE2 configuration..."
if [ -f /etc/rancher/rke2/config.yaml ]; then
    # Remove invalid feature gates from config
    sed -i '/feature-gates=SCTPSupport=false/d' /etc/rancher/rke2/config.yaml
    sed -i '/feature-gates=LocalStorageCapacityIsolation=false/d' /etc/rancher/rke2/config.yaml
    echo "✅ Removed invalid feature gates from config"
else
    echo "❌ Config file not found"
fi

# Remove the broken kubelet config if it exists
if [ -f /var/lib/kubelet/config.yaml ]; then
    echo "2. Removing broken kubelet config..."
    rm -f /var/lib/kubelet/config.yaml
    echo "✅ Removed broken kubelet config"
fi

# Create minimal working kubelet config
echo "3. Creating working kubelet config..."
mkdir -p /var/lib/kubelet
cat > /var/lib/kubelet/config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# LXC-compatible settings without invalid feature gates
failSwapOn: false
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///run/k3s/containerd/containerd.sock
runtimeRequestTimeout: 15m0s
maxPods: 250
serializeImagePulls: false
EOF

echo "4. Restarting RKE2..."
systemctl start rke2-server.service

echo "✅ FEATURE GATE FIX APPLIED!"
echo "Monitor with: journalctl -u rke2-server.service -f"
echo "The kubelet should now start without crashing!"
