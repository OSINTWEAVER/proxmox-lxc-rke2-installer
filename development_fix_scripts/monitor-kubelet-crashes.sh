#!/bin/bash
# Real-time RKE2 kubelet crash analysis
# Run this while RKE2 is starting to see what's causing kubelet to crash

echo "🔍 Real-time Kubelet Crash Analysis"
echo "===================================="

# Monitor kubelet crashes in real-time
echo "Monitoring RKE2 logs for kubelet issues..."
echo "Press Ctrl+C to stop monitoring"
echo ""

journalctl -u rke2-server.service -f --since "1 minute ago" | while read line; do
    if echo "$line" | grep -q "Kubelet exited"; then
        echo "🚨 KUBELET CRASH DETECTED: $line"
        
        # Try to get more detailed kubelet logs
        echo "📋 Getting detailed kubelet info..."
        
        # Check if kubelet process exists
        if pgrep kubelet >/dev/null; then
            echo "✅ Kubelet process is running"
        else
            echo "❌ No kubelet process found"
        fi
        
        # Check kubelet logs from containerd
        echo "📝 Recent kubelet activity:"
        journalctl -u rke2-server.service --since "30 seconds ago" | grep -i kubelet | tail -5
        
        echo "🔧 Container status:"
        if command -v crictl >/dev/null; then
            /var/lib/rancher/rke2/bin/crictl ps -a | head -5 2>/dev/null || echo "crictl not accessible"
        fi
        
        echo "💾 Memory and disk status:"
        free -h | head -2
        df -h / | tail -1
        
        echo "---"
    elif echo "$line" | grep -q "etcd"; then
        echo "📡 ETCD: $line"
    elif echo "$line" | grep -q "API server"; then
        echo "🌐 API: $line"
    fi
done
