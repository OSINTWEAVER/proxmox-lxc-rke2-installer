#!/bin/bash
# Direct kubelet log analysis - find the ROOT CAUSE

echo "🔍 ROOT CAUSE ANALYSIS: Kubelet Crash Investigation"
echo "=================================================="

echo "1. Checking kubelet log file..."
if [ -f /var/lib/rancher/rke2/agent/logs/kubelet.log ]; then
    echo "✅ Kubelet log file exists - checking last crash:"
    echo "--- LAST 20 LINES OF KUBELET LOG ---"
    tail -20 /var/lib/rancher/rke2/agent/logs/kubelet.log
else
    echo "❌ Kubelet log file missing - checking journalctl"
fi

echo ""
echo "2. Checking for specific kubelet errors..."
journalctl -u rke2-server.service --since "2 minutes ago" | grep -A 5 -B 5 "Kubelet exited" | tail -20

echo ""
echo "3. Checking container runtime connectivity..."
if command -v crictl >/dev/null 2>&1; then
    echo "Testing crictl connectivity..."
    timeout 10 /var/lib/rancher/rke2/bin/crictl version || echo "crictl failed"
    timeout 10 /var/lib/rancher/rke2/bin/crictl info || echo "crictl info failed"
else
    echo "crictl not available"
fi

echo ""
echo "4. Checking containerd socket..."
if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo "✅ Containerd socket exists"
    ls -la /run/k3s/containerd/containerd.sock
else
    echo "❌ Containerd socket missing!"
    ls -la /run/k3s/containerd/ || echo "Directory doesn't exist"
fi

echo ""
echo "5. Checking cgroup issues..."
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "Available cgroup controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
else
    echo "❌ cgroup v2 not available"
fi

echo ""
echo "6. Manual kubelet test (to see exact error)..."
echo "Attempting to run kubelet manually to see the exact failure..."

# Try to run kubelet directly to see the actual error
timeout 10 /var/lib/rancher/rke2/bin/kubelet \
    --config=/var/lib/kubelet/config.yaml \
    --container-runtime-endpoint=unix:///run/k3s/containerd/containerd.sock \
    --kubeconfig=/var/lib/rancher/rke2/agent/kubelet.kubeconfig \
    --fail-swap-on=false \
    --v=2 2>&1 | head -10 || echo "Kubelet manual test failed"

echo ""
echo "🔍 ROOT CAUSE INVESTIGATION COMPLETE"
