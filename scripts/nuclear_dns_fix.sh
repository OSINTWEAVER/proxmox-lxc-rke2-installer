#!/bin/bash

# NUCLEAR OPTION: Emergency DNS and kube-proxy restart for RKE2 clusters
# This script addresses critical DNS resolution failures in pods

echo "🚨 EMERGENCY NUCLEAR DNS FIX FOR RKE2"
echo "====================================="
echo "WARNING: This will restart critical cluster services!"
echo "Press Ctrl+C within 10 seconds to abort..."

for i in {10..1}; do
    echo "Starting in $i seconds..."
    sleep 1
done

echo ""
echo "🔥 EXECUTING NUCLEAR DNS FIX..."

# Step 1: Delete all stuck helm operations
echo "Step 1: Purging all stuck helm operations..."
kubectl delete pods -n cattle-system -l job-name --force --grace-period=0 2>/dev/null || true
kubectl delete jobs -n cattle-system -l helm.cattle.io/operation --force --grace-period=0 2>/dev/null || true

# Step 2: Get the actual service CIDR from kubernetes service
echo "Step 2: Auto-detecting cluster configuration..."
KUBERNETES_SVC_IP=$(kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}')
echo "Kubernetes service IP: $KUBERNETES_SVC_IP"

# Determine cluster and correct DNS IP
if [[ "$KUBERNETES_SVC_IP" =~ ^10\.43\. ]]; then
    CLUSTER_DNS="10.43.0.10"
    SERVICE_CIDR="10.43.0.0/16"
    POD_CIDR="10.42.0.0/16"
    echo "Detected Octostar cluster"
elif [[ "$KUBERNETES_SVC_IP" =~ ^10\.41\. ]]; then
    CLUSTER_DNS="10.41.0.10"
    SERVICE_CIDR="10.41.0.0/16"
    POD_CIDR="10.40.0.0/16"
    echo "Detected Iris cluster"
else
    echo "❌ Unknown cluster configuration!"
    exit 1
fi

echo "Using DNS IP: $CLUSTER_DNS"
echo "Service CIDR: $SERVICE_CIDR"
echo "Pod CIDR: $POD_CIDR"

# Step 3: Restart kube-proxy on all nodes (critical for service routing)
echo "Step 3: Restarting kube-proxy on all nodes..."
kubectl delete pods -n kube-system -l k8s-app=kube-proxy --force --grace-period=0

# Step 4: Restart CoreDNS completely
echo "Step 4: Force restarting CoreDNS..."
kubectl delete pods -n kube-system -l k8s-app=kube-dns --force --grace-period=0

# Step 5: Wait for services to come back up
echo "Step 5: Waiting for critical services to restart..."
kubectl wait --for=condition=Ready pod -l k8s-app=kube-proxy -n kube-system --timeout=120s
kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s

# Step 6: Restart RKE2 service to reset networking stack
echo "Step 6: Restarting RKE2 service to reset networking..."
systemctl restart rke2-server 2>/dev/null || systemctl restart rke2-agent 2>/dev/null

# Step 7: Wait for cluster to stabilize
echo "Step 7: Waiting for cluster to stabilize..."
sleep 60

# Step 8: Test DNS resolution from a fresh pod
echo "Step 8: Testing DNS resolution..."
kubectl run dns-nuclear-test --image=busybox --rm -it --restart=Never --command -- sh -c "
nslookup kubernetes.default;
echo '--- Testing service resolution ---';
nslookup kubernetes.default.svc.cluster.local;
echo '--- Testing external resolution ---';
nslookup google.com;
" 2>&1 || echo "DNS test completed (some failures expected during restart)"

# Step 9: Verify service endpoints
echo "Step 9: Verifying cluster services..."
kubectl get svc kubernetes -o wide
kubectl get endpoints kubernetes
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Step 10: Check for remaining helm operations
echo "Step 10: Checking for helm operations..."
HELM_COUNT=$(kubectl get pods -n cattle-system -l job-name --no-headers 2>/dev/null | wc -l || echo "0")
echo "Current helm operations: $HELM_COUNT"

if [ "$HELM_COUNT" -gt 0 ]; then
    echo "⚠️  Some helm operations may restart - this is normal"
    echo "Monitor with: kubectl get pods -n cattle-system -l job-name"
else
    echo "✅ No helm operations currently running"
fi

echo ""
echo "🎯 NUCLEAR DNS FIX COMPLETE!"
echo "============================="
echo "Monitor cluster health with:"
echo "  kubectl get nodes"
echo "  kubectl get pods -n cattle-system"
echo "  kubectl get pods -n kube-system -l k8s-app=kube-dns"
echo ""
echo "If issues persist, the cluster may need to be rebuilt."
