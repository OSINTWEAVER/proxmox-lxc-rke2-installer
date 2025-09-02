#!/bin/bash
# FIO Benchmark Cleanup Script

echo "🧹 Cleaning up FIO Benchmark Deployment"
echo "======================================="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

echo "🔍 Checking for FIO benchmark resources..."

# Check if resources exist
HAS_RESOURCES=false

if kubectl get deployment fio-benchmark-web >/dev/null 2>&1; then
    echo "   ✅ Found web dashboard deployment"
    HAS_RESOURCES=true
fi

if kubectl get daemonset fio-benchmark >/dev/null 2>&1; then
    echo "   ✅ Found FIO benchmark daemonsets"
    HAS_RESOURCES=true
fi

if kubectl get configmap fio-benchmark-web >/dev/null 2>&1; then
    echo "   ✅ Found FIO benchmark configmaps"
    HAS_RESOURCES=true
fi

if [ "$HAS_RESOURCES" = false ]; then
    echo "   ℹ️  No FIO benchmark resources found - nothing to clean up!"
    exit 0
fi

echo ""
echo "📋 Resources to be removed:"
kubectl get deployment,daemonset,service,configmap,ingress -l app=fio-benchmark 2>/dev/null || true
kubectl get deployment,service,ingress -l app=fio-benchmark-web 2>/dev/null || true

echo ""
read -p "🗑️  Proceed with cleanup? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 Removing FIO benchmark resources..."
    
    # Delete using the YAML file if it exists
    if [ -f "fio-benchmark-test.yaml" ]; then
        kubectl delete -f fio-benchmark-test.yaml --ignore-not-found=true
    else
        # Manual cleanup if YAML not available
        kubectl delete deployment fio-benchmark-web --ignore-not-found=true
        kubectl delete daemonset fio-benchmark fio-benchmark-gpu2 --ignore-not-found=true
        kubectl delete service fio-benchmark-web-service --ignore-not-found=true
        kubectl delete configmap fio-benchmark-web fio-benchmark-scripts --ignore-not-found=true
        kubectl delete ingress fio-benchmark-ingress --ignore-not-found=true
    fi
    
    echo ""
    echo "⏳ Waiting for pods to terminate..."
    kubectl wait --for=delete pod -l app=fio-benchmark --timeout=60s 2>/dev/null || true
    kubectl wait --for=delete pod -l app=fio-benchmark-web --timeout=60s 2>/dev/null || true
    
    echo ""
    echo "🔍 Verifying cleanup..."
    REMAINING=$(kubectl get all -l app=fio-benchmark -o name 2>/dev/null | wc -l)
    REMAINING_WEB=$(kubectl get all -l app=fio-benchmark-web -o name 2>/dev/null | wc -l)
    
    if [ "$REMAINING" -eq 0 ] && [ "$REMAINING_WEB" -eq 0 ]; then
        echo "✅ Cleanup completed successfully!"
    else
        echo "⚠️  Some resources may still be terminating:"
        kubectl get all -l app=fio-benchmark 2>/dev/null || true
        kubectl get all -l app=fio-benchmark-web 2>/dev/null || true
    fi
    
    echo ""
    echo "🧽 Optional: Clean up any remaining test files on nodes"
    echo "   You can SSH to each GPU node and run:"
    echo "   sudo rm -rf /tmp/fio-test"
    
else
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "🎉 FIO Benchmark cleanup complete!"
