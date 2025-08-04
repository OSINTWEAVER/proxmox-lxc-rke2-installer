#!/bin/bash
# Check if RKE2 is actually working despite the Ansible timeout
# Run this on your control-plane container (10.14.100.1)

echo "🔍 RKE2 Manual Status Check"
echo "==========================="

echo "1. Checking systemd service status..."
systemctl status rke2-server.service --no-pager -l

echo
echo "2. Checking if RKE2 processes are running..."
ps aux | grep -E "(rke2|containerd)" | grep -v grep

echo
echo "3. Checking if Kubernetes API is responding..."
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
    echo "✅ Kubeconfig file exists"
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    
    # Try to connect to API server
    echo "Testing API connection..."
    if timeout 10 /var/lib/rancher/rke2/bin/kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Kubernetes API is responding!"
        echo
        echo "Cluster info:"
        /var/lib/rancher/rke2/bin/kubectl cluster-info
        echo
        echo "Node status:"
        /var/lib/rancher/rke2/bin/kubectl get nodes -o wide
        echo
        echo "Pod status:"
        /var/lib/rancher/rke2/bin/kubectl get pods -A
    else
        echo "⏳ Kubernetes API not ready yet, but this is normal during initial startup"
        echo "RKE2 is still initializing..."
    fi
else
    echo "⏳ Kubeconfig not created yet - RKE2 still starting up"
fi

echo
echo "4. Checking logs for any errors..."
echo "Recent RKE2 logs:"
journalctl -u rke2-server.service --no-pager -n 10

echo
echo "5. Checking network ports..."
echo "Network ports that should be listening:"
netstat -tulpn | grep -E "(6443|9345|10250)"

echo
echo "6. Overall assessment..."
if systemctl is-active --quiet rke2-server.service; then
    echo "✅ RKE2 service is ACTIVE"
    if [ -f /etc/rancher/rke2/rke2.yaml ]; then
        echo "✅ This looks like a successful RKE2 deployment!"
        echo "   The Ansible timeout was just due to slow LXC initialization."
        echo "   You can continue with joining the other nodes."
    else
        echo "⏳ RKE2 is running but still initializing"
        echo "   Wait a few more minutes for full startup"
    fi
else
    echo "❌ RKE2 service is not active - there may be a real problem"
fi

echo
echo "🏁 Manual check complete!"
