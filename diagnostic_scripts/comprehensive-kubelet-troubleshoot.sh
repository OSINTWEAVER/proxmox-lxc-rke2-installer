#!/bin/bash
# Comprehensive kubelet troubleshooting for LXC

echo "🔧 COMPREHENSIVE KUBELET LXC TROUBLESHOOTING"
echo "============================================"

echo "1. Checking if /dev/kmsg exists..."
if [ -L /dev/kmsg ]; then
    echo "✅ /dev/kmsg -> $(readlink /dev/kmsg)"
else
    echo "❌ /dev/kmsg missing - creating it..."
    ln -sf /dev/null /dev/kmsg
fi

echo ""
echo "2. Checking kubelet config file..."
if [ -f /var/lib/kubelet/config.yaml ]; then
    echo "✅ Kubelet config exists"
    echo "--- CONFIG CONTENT ---"
    cat /var/lib/kubelet/config.yaml
else
    echo "❌ Kubelet config missing"
fi

echo ""
echo "3. Checking RKE2 config..."
if [ -f /etc/rancher/rke2/config.yaml ]; then
    echo "✅ RKE2 config exists"
    echo "--- RKE2 CONFIG ---"
    cat /etc/rancher/rke2/config.yaml
else
    echo "❌ RKE2 config missing"
fi

echo ""
echo "4. Checking latest kubelet logs..."
if [ -f /var/lib/rancher/rke2/agent/logs/kubelet.log ]; then
    echo "--- LAST 10 LINES OF KUBELET LOG ---"
    tail -10 /var/lib/rancher/rke2/agent/logs/kubelet.log
else
    echo "❌ Kubelet log not found"
fi

echo ""
echo "5. Manually testing kubelet startup..."
systemctl stop rke2-server.service
sleep 2

# Try to run kubelet directly to see the exact error
echo "Attempting direct kubelet execution..."
timeout 10 /var/lib/rancher/rke2/bin/kubelet \
    --config=/var/lib/kubelet/config.yaml \
    --container-runtime-endpoint=unix:///run/k3s/containerd/containerd.sock \
    --kubeconfig=/var/lib/rancher/rke2/agent/kubelet.kubeconfig \
    --hostname-override=10.14.100.1 \
    --v=2 || echo "Kubelet failed with exit code $?"

echo ""
echo "6. Checking container runtime..."
if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo "✅ Containerd socket exists"
else
    echo "❌ Containerd socket missing"
fi

echo ""
echo "7. Checking system requirements..."
echo "Available memory: $(free -h | grep Mem: | awk '{print $7}')"
echo "Available disk: $(df -h /var/lib/rancher | tail -1 | awk '{print $4}')"

echo ""
echo "8. Restarting RKE2..."
systemctl start rke2-server.service

echo "✅ COMPREHENSIVE TROUBLESHOOTING COMPLETE"
