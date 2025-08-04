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
if command -v docker >/dev/null 2>&1; then
    echo "Testing Docker connectivity..."
    timeout 10 docker version || echo "Docker version failed"
    timeout 10 docker info | grep -i "runtime\|storage" || echo "Docker info failed"
else
    echo "❌ Docker not available"
fi

echo ""
echo "4. Checking Docker socket..."
if [ -S /run/docker.sock ]; then
    echo "✅ Docker socket exists at /run/docker.sock"
    ls -la /run/docker.sock
elif [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket exists at /var/run/docker.sock"
    ls -la /var/run/docker.sock
else
    echo "❌ Docker socket missing!"
    echo "Checking locations:"
    ls -la /run/docker.sock 2>/dev/null || echo "Not found at /run/docker.sock"
    ls -la /var/run/docker.sock 2>/dev/null || echo "Not found at /var/run/docker.sock"
fi

echo ""
echo "5. Checking cgroup issues..."
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "Available cgroup controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
else
    echo "❌ cgroup v2 not available"
fi

echo ""
echo "6. Checking kubelet configuration file..."
if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
    echo "✅ Kubelet config file exists"
    echo "--- CONFIG FILE SIZE ---"
    ls -la /etc/rancher/rke2/kubelet-config.yaml
    echo "--- CONFIG FILE CONTENT (first 10 lines) ---"
    head -10 /etc/rancher/rke2/kubelet-config.yaml
else
    echo "❌ Kubelet config file missing at /etc/rancher/rke2/kubelet-config.yaml"
fi

echo ""
echo "7. Manual kubelet test (to see exact error)..."
echo "Attempting to run kubelet manually to see the exact failure..."

# Try to run kubelet directly to see the actual error
timeout 10 /var/lib/rancher/rke2/bin/kubelet \
    --config=/etc/rancher/rke2/kubelet-config.yaml \
    --kubeconfig=/var/lib/rancher/rke2/agent/kubelet.kubeconfig \
    --v=2 2>&1 | head -10 || echo "Kubelet manual test failed"

echo ""
echo "🔍 ROOT CAUSE INVESTIGATION COMPLETE"
