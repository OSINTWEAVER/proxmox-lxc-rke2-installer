#!/bin/bash
# Advanced RKE2 LXC Startup Monitor
# This monitors the complete RKE2 startup process and provides detailed diagnostics

echo "🔍 RKE2 LXC STARTUP MONITOR"
echo "=========================="
echo "Monitoring cluster initialization - this will run for 10 minutes"
echo ""

# Function to check service status
check_service_status() {
    if systemctl is-active --quiet rke2-server.service; then
        echo "✅ RKE2 service: ACTIVE"
        return 0
    else
        echo "❌ RKE2 service: INACTIVE"
        return 1
    fi
}

# Function to check for kubelet crashes
check_kubelet_crashes() {
    local crashes=$(journalctl -u rke2-server.service --since "1 minute ago" | grep -c "Kubelet exited" || echo "0")
    if [ "$crashes" -eq 0 ]; then
        echo "✅ Kubelet: STABLE (0 crashes in last minute)"
        return 0
    else
        echo "❌ Kubelet: $crashes crashes in last minute"
        return 1
    fi
}

# Function to check API server
check_api_server() {
    if [ -f /etc/rancher/rke2/rke2.yaml ]; then
        echo "✅ Kubeconfig: EXISTS"
        
        if timeout 10 /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml cluster-info >/dev/null 2>&1; then
            echo "✅ API Server: RESPONDING"
            return 0
        else
            echo "⏳ API Server: NOT READY"
            return 1
        fi
    else
        echo "⏳ Kubeconfig: NOT CREATED YET"
        return 1
    fi
}

# Function to check etcd
check_etcd() {
    if netstat -tlpn 2>/dev/null | grep -q ":2379"; then
        echo "✅ etcd: LISTENING on port 2379"
        return 0
    else
        echo "⏳ etcd: NOT LISTENING"
        return 1
    fi
}

# Function to check nodes
check_nodes() {
    if [ -f /etc/rancher/rke2/rke2.yaml ]; then
        local nodes=$(/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes --no-headers 2>/dev/null | wc -l)
        local ready_nodes=$(/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
        
        if [ "$nodes" -gt 0 ]; then
            echo "✅ Nodes: $ready_nodes/$nodes Ready"
            return 0
        else
            echo "⏳ Nodes: NOT READY"
            return 1
        fi
    else
        echo "⏳ Nodes: CANNOT CHECK (no kubeconfig)"
        return 1
    fi
}

# Function to check system pods
check_system_pods() {
    if [ -f /etc/rancher/rke2/rke2.yaml ]; then
        local total_pods=$(/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -A --no-headers 2>/dev/null | wc -l)
        local running_pods=$(/var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -A --no-headers 2>/dev/null | grep -c " Running " || echo "0")
        
        if [ "$total_pods" -gt 0 ]; then
            echo "✅ System Pods: $running_pods/$total_pods Running"
            if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 5 ]; then
                return 0
            else
                return 1
            fi
        else
            echo "⏳ System Pods: NOT CREATED YET"
            return 1
        fi
    else
        echo "⏳ System Pods: CANNOT CHECK (no kubeconfig)"
        return 1
    fi
}

# Function to show recent errors
show_recent_errors() {
    echo ""
    echo "🚨 Recent errors/warnings (last 2 minutes):"
    journalctl -u rke2-server.service --since "2 minutes ago" | grep -E "(ERROR|WARN|error|failed)" | tail -5 || echo "   No recent errors found"
}

# Function to show LXC-specific status
show_lxc_status() {
    echo ""
    echo "🔧 LXC Container Status:"
    
    # Check kernel parameters
    local readonly_params=""
    for param in vm/overcommit_memory kernel/panic kernel/panic_on_oops; do
        if [ -f "/proc/sys/$param" ]; then
            if ! echo "test" > "/proc/sys/$param" 2>/dev/null; then
                readonly_params="$readonly_params $param"
            fi
        fi
    done
    
    if [ -n "$readonly_params" ]; then
        echo "⚠️  Read-only kernel params: $readonly_params (expected in LXC)"
    else
        echo "✅ All kernel parameters writable"
    fi
    
    # Check /dev/kmsg
    if [ -L /dev/kmsg ]; then
        echo "✅ /dev/kmsg: $(readlink /dev/kmsg)"
    else
        echo "❌ /dev/kmsg: MISSING"
    fi
    
    # Check kubelet config files
    if [ -f /var/lib/kubelet/config.yaml ]; then
        echo "❌ /var/lib/kubelet/config.yaml: EXISTS (should be removed for LXC)"
    else
        echo "✅ /var/lib/kubelet/config.yaml: NOT PRESENT (good for LXC)"
    fi
    
    if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
        echo "❌ /etc/rancher/rke2/kubelet-config.yaml: EXISTS (should be removed for LXC)"
    else
        echo "✅ /etc/rancher/rke2/kubelet-config.yaml: NOT PRESENT (good for LXC)"
    fi
}

# Main monitoring loop
echo "Starting 10-minute monitoring session..."
echo "Press Ctrl+C to stop early"
echo ""

start_time=$(date +%s)
cluster_ready=false

for i in {1..60}; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    echo "=== Check $i/60 (${elapsed}s elapsed) ==="
    
    # Basic service checks
    service_ok=$(check_service_status; echo $?)
    kubelet_ok=$(check_kubelet_crashes; echo $?)
    etcd_ok=$(check_etcd; echo $?)
    api_ok=$(check_api_server; echo $?)
    nodes_ok=$(check_nodes; echo $?)
    pods_ok=$(check_system_pods; echo $?)
    
    # Check if cluster is fully ready
    if [ "$service_ok" -eq 0 ] && [ "$kubelet_ok" -eq 0 ] && [ "$etcd_ok" -eq 0 ] && [ "$api_ok" -eq 0 ] && [ "$nodes_ok" -eq 0 ] && [ "$pods_ok" -eq 0 ]; then
        echo ""
        echo "🎉 CLUSTER IS READY! All components are healthy."
        cluster_ready=true
        break
    fi
    
    # Show errors every 5 checks or when there are issues
    if [ $((i % 5)) -eq 0 ] || [ "$service_ok" -ne 0 ] || [ "$kubelet_ok" -ne 0 ]; then
        show_recent_errors
    fi
    
    # Show LXC status every 10 checks
    if [ $((i % 10)) -eq 0 ]; then
        show_lxc_status
    fi
    
    echo ""
    sleep 10
done

echo ""
echo "🏁 MONITORING COMPLETE"
echo "======================"

if [ "$cluster_ready" = true ]; then
    echo "✅ SUCCESS: RKE2 cluster is fully operational!"
    echo ""
    echo "Next steps:"
    echo "1. Export kubeconfig: export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
    echo "2. Check nodes: /var/lib/rancher/rke2/bin/kubectl get nodes -o wide"
    echo "3. Check pods: /var/lib/rancher/rke2/bin/kubectl get pods -A"
    echo "4. Join worker nodes to the cluster"
else
    echo "⚠️  INCOMPLETE: Cluster is not fully ready yet"
    echo ""
    echo "Current status:"
    check_service_status
    check_kubelet_crashes
    check_etcd
    check_api_server
    check_nodes
    check_system_pods
    
    show_recent_errors
    show_lxc_status
    
    echo ""
    echo "Recommendations:"
    echo "1. Continue monitoring: journalctl -u rke2-server.service -f"
    echo "2. Check for specific errors in the logs above"
    echo "3. Allow more time - LXC containers can be slower to initialize"
fi
