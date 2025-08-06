#!/bin/bash
# NVIDIA Container Runtime Fix for RKE2 in LXC Containers
# This script fixes the missing nvidia-container-runtime configuration
# Run this script on each GPU node that has NVIDIA devices

set -e

echo "🔧 NVIDIA Container Runtime Fix for RKE2 LXC Deployment"
echo "========================================================"

# Check if running in LXC
if ! grep -qa container=lxc /proc/1/environ 2>/dev/null; then
    echo "❌ ERROR: This script is designed for LXC containers only"
    exit 1
fi

# Check if NVIDIA devices are available
if [ ! -e "/dev/nvidia0" ]; then
    echo "ℹ️  INFO: No NVIDIA devices found - skipping NVIDIA setup"
    exit 0
fi

echo "✅ NVIDIA devices detected - proceeding with Container Runtime setup"

# Step 1: Add NVIDIA Container Toolkit repository
echo "📦 Adding NVIDIA Container Toolkit repository..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Step 2: Update package cache
echo "🔄 Updating package cache..."
sudo apt update

# Step 3: Install NVIDIA Container Toolkit
echo "📦 Installing NVIDIA Container Toolkit..."
sudo apt install -y nvidia-container-toolkit nvidia-container-runtime

# Step 4: Backup existing containerd config
echo "💾 Backing up existing containerd configuration..."
sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.backup.$(date +%Y%m%d_%H%M%S)

# Step 5: Generate new containerd configuration with NVIDIA runtime
echo "⚙️  Configuring containerd with NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=containerd --config=/etc/containerd/config.toml

# Step 6: Restart containerd service
echo "🔄 Restarting containerd service..."
sudo systemctl restart containerd

# Step 7: Restart RKE2 service (if running)
echo "🔄 Restarting RKE2 service..."
if systemctl is-active --quiet rke2-server; then
    echo "   Restarting RKE2 server..."
    sudo systemctl restart rke2-server
elif systemctl is-active --quiet rke2-agent; then
    echo "   Restarting RKE2 agent..."
    sudo systemctl restart rke2-agent
else
    echo "   No active RKE2 service found - manual restart may be needed"
fi

# Step 8: Verify NVIDIA runtime installation
echo "🔍 Verifying NVIDIA Container Runtime installation..."
if command -v nvidia-container-runtime >/dev/null 2>&1; then
    echo "✅ nvidia-container-runtime is available at: $(which nvidia-container-runtime)"
else
    echo "❌ ERROR: nvidia-container-runtime not found in PATH"
    exit 1
fi

# Step 9: Test containerd configuration
echo "🧪 Testing containerd configuration..."
if sudo containerd config dump | grep -q "nvidia"; then
    echo "✅ NVIDIA runtime found in containerd configuration"
else
    echo "❌ WARNING: NVIDIA runtime not found in containerd configuration"
fi

echo ""
echo "🎉 NVIDIA Container Runtime setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Wait 5-10 minutes for GPU operator pods to restart"
echo "2. Check GPU operator status: kubectl get pods -n gpu-operator"
echo "3. If issues persist, delete GPU operator pods to force restart:"
echo "   kubectl delete pods -n gpu-operator --all"
echo ""
echo "🔧 Troubleshooting:"
echo "- Check containerd logs: sudo journalctl -u containerd -f"
echo "- Check RKE2 logs: sudo journalctl -u rke2-server -f (or rke2-agent)"
echo "- Verify GPU access: ls -la /dev/nvidia*"
echo ""
