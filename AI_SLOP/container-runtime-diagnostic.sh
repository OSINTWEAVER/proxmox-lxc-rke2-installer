#!/bin/bash
# Comprehensive container runtime diagnostic tool for RKE2 in LXC
set -e

echo "🔍 RKE2 CONTAINER RUNTIME DIAGNOSTICS"
echo "===================================="

echo "1. SYSTEM INFORMATION"
echo "---------------------"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"

echo ""
echo "2. RKE2 STATUS"
echo "--------------"
systemctl status rke2-server.service || true
systemctl status rke2-minimal.service || true

echo ""
echo "3. ENVIRONMENT VARIABLES"
echo "------------------------"
echo "PATH: $PATH"
echo "CONTAINERD_ADDRESS: ${CONTAINERD_ADDRESS:-not set}"
echo "CONTAINER_RUNTIME_ENDPOINT: ${CONTAINER_RUNTIME_ENDPOINT:-not set}"

echo ""
echo "4. CGROUP CONFIGURATION"
echo "-----------------------"
echo "Cgroup v2 enabled: $(test -f /sys/fs/cgroup/cgroup.controllers && echo Yes || echo No)"
ls -la /sys/fs/cgroup/ | head -10
cat /proc/self/cgroup | head -10

echo ""
echo "5. NETWORK CONFIGURATION"
echo "------------------------"
echo "IP Forwarding: $(sysctl -n net.ipv4.ip_forward)"
echo "Bridge Netfilter: $(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo 'Not loaded')"
ip addr show

echo ""
echo "6. CONTAINERD STATUS"
echo "--------------------"
if [ -S /run/k3s/containerd/containerd.sock ]; then
  echo "Containerd socket exists"
  ls -la /run/k3s/containerd/containerd.sock
  
  # Check if we can reach containerd
  if command -v ctr >/dev/null 2>&1; then
    CONTAINERD_NS="k8s.io"
    echo "Checking containerd with 'ctr'..."
    echo "Namespaces:"
    CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock ctr namespace ls || echo "Failed to list namespaces"
    
    echo "Containers:"
    CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock ctr -n "$CONTAINERD_NS" container ls || echo "Failed to list containers"
    
    echo "Images:"
    CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock ctr -n "$CONTAINERD_NS" image ls || echo "Failed to list images"
  else
    echo "ctr command not found"
  fi
else
  echo "Containerd socket NOT found"
fi

echo ""
echo "7. RKE2 DIRECTORY STRUCTURE"
echo "---------------------------"
echo "RKE2 Bin Directory:"
ls -la /var/lib/rancher/rke2/bin/ | head -20
echo "RKE2 Data Directory:"
ls -la /var/lib/rancher/rke2/server/ | head -20

echo ""
echo "8. SQLITE DATABASE (If Enabled)"
echo "-------------------------------"
if [ -f /var/lib/rancher/rke2/server/db/state.db ]; then
  echo "SQLite database exists"
  ls -la /var/lib/rancher/rke2/server/db/
  echo "Database size: $(du -sh /var/lib/rancher/rke2/server/db/state.db)"
else
  echo "No SQLite database found"
fi

echo ""
echo "9. LAST 50 LINES OF RKE2 LOGS"
echo "-----------------------------"
journalctl -u rke2-server.service -n 50 --no-pager || journalctl -u rke2-minimal.service -n 50 --no-pager || echo "No logs found"

echo ""
echo "10. KUBELET STATUS"
echo "-----------------"
echo "Kubelet process:"
ps aux | grep kubelet | grep -v grep

echo "Kubelet directory:"
ls -la /var/lib/kubelet/ | head -20

echo ""
echo "DIAGNOSTICS COMPLETED"
echo "====================="
echo "Run this again after making changes to compare results"
