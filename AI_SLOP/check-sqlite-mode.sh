#!/bin/bash
# Check if SQLite-based RKE2 is working correctly

echo "🔍 CHECKING SQLITE-BASED RKE2 DEPLOYMENT"
echo "========================================"

# Check if RKE2 service is running
echo "1. Checking RKE2 service status..."
if systemctl is-active rke2-minimal >/dev/null 2>&1; then
  echo "✅ RKE2 service is running"
else
  if systemctl is-active rke2-server >/dev/null 2>&1; then
    echo "✅ RKE2 server service is running"
  else
    echo "❌ RKE2 service is not running!"
    echo "Try running: systemctl status rke2-minimal || systemctl status rke2-server"
    exit 1
  fi
fi

# Check if SQLite database exists
echo "2. Checking SQLite database..."
if [ -f /var/lib/rancher/rke2/server/db/state.db ]; then
  echo "✅ SQLite database exists"
  SQLITE_SIZE=$(du -h /var/lib/rancher/rke2/server/db/state.db | awk '{print $1}')
  echo "   Database size: $SQLITE_SIZE"
else
  echo "❌ SQLite database not found!"
  echo "This deployment is not using SQLite mode. Check your configuration."
  exit 1
fi

# Check if kubelet is patched
echo "3. Checking kubelet wrapper..."
if grep -q "kubelet-wrapper.sh" /var/lib/rancher/rke2/bin/kubelet 2>/dev/null; then
  echo "✅ Kubelet is patched with wrapper script"
else
  echo "⚠️ Kubelet is not patched with wrapper script"
  echo "   This may cause resource management issues"
fi

# Check if kubectl is available
echo "4. Checking kubectl availability..."
if [ -f /var/lib/rancher/rke2/bin/kubectl ]; then
  echo "✅ kubectl command is available"
else
  echo "⚠️ kubectl command not found at expected location"
fi

# Export kubeconfig if available
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
  
  echo "5. Checking node status..."
  NODE_STATUS=$(/var/lib/rancher/rke2/bin/kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  
  if [ "$NODE_STATUS" == "True" ]; then
    echo "✅ Node is Ready"
    echo ""
    echo "Node details:"
    /var/lib/rancher/rke2/bin/kubectl get nodes -o wide
  else
    echo "⚠️ Node is not Ready"
    echo "   Check node status with: export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl get nodes"
  fi
  
  echo ""
  echo "6. Checking system pods..."
  RUNNING_PODS=$(/var/lib/rancher/rke2/bin/kubectl get pods -A --field-selector=status.phase=Running 2>/dev/null | wc -l)
  if [ "$RUNNING_PODS" -gt 1 ]; then
    echo "✅ System pods are running ($((RUNNING_PODS-1)) pods)"
    echo ""
    echo "Pod status:"
    /var/lib/rancher/rke2/bin/kubectl get pods -A
  else
    echo "⚠️ Few or no pods are running"
    echo "   Check pod status with: export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl get pods -A"
  fi
else
  echo "5. ❌ Kubeconfig not found at /etc/rancher/rke2/rke2.yaml"
  echo "   Cannot check cluster status"
fi

echo ""
echo "✅ SQLITE MODE CHECK COMPLETE"
echo "============================"
if [ "$NODE_STATUS" == "True" ] && [ "$RUNNING_PODS" -gt 1 ]; then
  echo "SQLite-based RKE2 deployment appears to be working correctly!"
else
  echo "SQLite-based RKE2 deployment has some issues that need to be addressed."
  echo "Check the logs with: journalctl -u rke2-minimal -f || journalctl -u rke2-server -f"
fi
