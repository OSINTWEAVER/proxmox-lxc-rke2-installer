#!/bin/bash

# Emergency fix script for RKE2 helm operation loops with corrected DNS configuration
# This version uses the correct service CIDR DNS IPs instead of pod CIDR

echo "🚨 EMERGENCY RKE2 HELM OPERATION FIX (CORRECTED DNS)"
echo "===================================================="

# Step 1: Stop any running helm operation pods
echo "Step 1: Stopping problematic helm operations..."
kubectl delete pods -n cattle-system -l job-name --timeout=30s 2>/dev/null || true
kubectl delete jobs -n cattle-system -l helm.cattle.io/operation --timeout=30s 2>/dev/null || true

# Step 2: Detect correct DNS IP based on service CIDR
echo "Step 2: Detecting correct DNS configuration..."

# Get the kubernetes service IP to determine the service CIDR
KUBERNETES_SVC_IP=$(kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [[ "$KUBERNETES_SVC_IP" =~ ^10\.43\. ]]; then
    # Octostar cluster (service CIDR: 10.43.0.0/16)
    CLUSTER_DNS="10.43.0.10"
    echo "Detected Octostar cluster - using DNS IP: $CLUSTER_DNS"
elif [[ "$KUBERNETES_SVC_IP" =~ ^10\.41\. ]]; then
    # Iris cluster (service CIDR: 10.41.0.0/16)  
    CLUSTER_DNS="10.41.0.10"
    echo "Detected Iris cluster - using DNS IP: $CLUSTER_DNS"
else
    echo "⚠️  Unknown cluster configuration, kubernetes service IP: $KUBERNETES_SVC_IP"
    echo "Attempting auto-detection of DNS IP..."
    
    # Try to find CoreDNS service
    COREDNS_IP=$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
    if [ -n "$COREDNS_IP" ]; then
        CLUSTER_DNS="$COREDNS_IP"
        echo "Found CoreDNS service at: $CLUSTER_DNS"
    else
        echo "❌ Could not detect DNS IP - manual intervention required"
        exit 1
    fi
fi

# Step 3: Test DNS resolution before fix
echo "Step 3: Testing DNS resolution..."
if nslookup kubernetes.default $CLUSTER_DNS >/dev/null 2>&1; then
    echo "✅ DNS resolution working correctly"
else
    echo "❌ DNS resolution failed - applying fixes"
    # Restart CoreDNS
    kubectl rollout restart deployment/rke2-coredns-rke2-coredns -n kube-system
fi

# Step 4: Check service endpoints
echo "Step 4: Checking service endpoints..."
kubectl get svc kubernetes -o wide
kubectl get endpoints kubernetes

# Step 5: Restart critical services
echo "Step 5: Restarting critical services..."
systemctl restart rke2-server 2>/dev/null || systemctl restart rke2-agent 2>/dev/null || true

# Step 6: Wait for CoreDNS to be ready
echo "Step 6: Verifying fix..."
kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

# Test DNS resolution again
if timeout 10 nslookup kubernetes.default $CLUSTER_DNS >/dev/null 2>&1; then
    echo "✅ DNS resolution now working"
else
    echo "❌ DNS still failing - checking detailed resolution"
    
    # Create a test pod to check DNS from inside the cluster
    kubectl run dns-test-fix --image=busybox --rm -it --restart=Never --command -- nslookup kubernetes.default $CLUSTER_DNS 2>&1 || true
    
    echo "✗ DNS still failing - manual intervention required"
fi

# Step 7: Clean up any remaining helm operations
echo "Step 7: Cleaning up helm operations..."
kubectl get pods -n cattle-system -l job-name 2>/dev/null | grep -v "NAME" | wc -l || echo "0"

echo "========================================"
echo "Fix complete. Monitor with:"
echo "kubectl get pods -n cattle-system -l job-name"
echo "kubectl logs -f -n cattle-system -l job-name"
echo "========================================"
