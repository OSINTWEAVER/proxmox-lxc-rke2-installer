#!/bin/bash
# Emergency Fix for Helm Operation Loop Issue
# This script addresses the DNS resolution and proxy connection failures

echo "🚨 EMERGENCY RKE2 HELM OPERATION FIX"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo "Step 1: Stopping problematic helm operations..."
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Delete stuck helm operations
kubectl delete pods -n cattle-system -l job-name --field-selector=status.phase=Failed --timeout=30s 2>/dev/null
kubectl delete pods -n cattle-system -l job-name --field-selector=status.phase=Pending --timeout=30s 2>/dev/null

echo "Step 2: Checking DNS resolution..."
# Auto-detect cluster DNS IP from kubelet config or service
CLUSTER_DNS_IP=$(grep -A2 "clusterDNS" /etc/rancher/rke2/kubelet-config.yaml 2>/dev/null | grep -E "^\s*-\s*" | head -1 | sed 's/.*- *"\?\([0-9.]*\)"\?.*/\1/')
if [ -z "$CLUSTER_DNS_IP" ]; then
    # Fallback: get DNS service IP directly from cluster
    CLUSTER_DNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
fi
if [ -z "$CLUSTER_DNS_IP" ]; then
    CLUSTER_DNS_IP="10.43.0.10"  # Default fallback
fi

echo "Using cluster DNS IP: $CLUSTER_DNS_IP"

# Test if kubernetes.default can be resolved
nslookup kubernetes.default.svc.cluster.local $CLUSTER_DNS_IP >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}DNS resolution failed - applying fixes${NC}"
    
    # Restart CoreDNS
    kubectl rollout restart deployment/rke2-coredns-rke2-coredns -n kube-system 2>/dev/null
    sleep 10
fi

echo "Step 3: Checking service endpoints..."
# Verify kubernetes service exists
kubectl get svc kubernetes -o wide
kubectl get endpoints kubernetes -o wide

echo "Step 4: Restarting critical services..."
# Restart RKE2 service
systemctl restart rke2-server.service 2>/dev/null || systemctl restart rke2-agent.service 2>/dev/null
sleep 30

echo "Step 5: Verifying fix..."
# Wait for system to stabilize
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s

# Test DNS again
kubectl run dns-test-fix --image=busybox --rm -it --restart=Never --timeout=30s -- nslookup kubernetes.default 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ DNS resolution fixed${NC}"
else
    echo -e "${RED}✗ DNS still failing - manual intervention required${NC}"
fi

echo "Step 6: Cleaning up helm operations..."
# Force cleanup of helm operations that are stuck
kubectl get jobs -n cattle-system -o jsonpath='{.items[?(@.status.failed>=1)].metadata.name}' | xargs -r kubectl delete job -n cattle-system
kubectl get pods -n cattle-system -l job-name | grep -E "(Error|CrashLoopBackOff|Pending)" | awk '{print $1}' | xargs -r kubectl delete pod -n cattle-system

echo "========================================"
echo "Fix complete. Monitor with:"
echo "kubectl get pods -n cattle-system -l job-name"
echo "kubectl logs -f -n cattle-system -l job-name"
echo "========================================"
