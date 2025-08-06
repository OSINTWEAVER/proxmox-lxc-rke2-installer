#!/bin/bash
# FIO Disk Performance Benchmark Deployment Script

echo "🚀 Deploying FIO Disk Performance Benchmarks"
echo "============================================="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Check if existing deployment should be cleaned up
echo "🔍 Checking for existing FIO benchmark deployment..."
if kubectl get deployment fio-benchmark-web >/dev/null 2>&1; then
    echo "⚠️  Existing FIO benchmark deployment found!"
    echo "🧹 Automatically cleaning up existing deployment..."
    kubectl delete -f fio-benchmark-test.yaml --ignore-not-found=true
    echo "✅ Cleanup completed!"
    echo ""
    sleep 3
fi

echo "📋 Cluster Status:"
kubectl get nodes -o wide

echo ""
echo "🔧 Deploying FIO benchmark infrastructure..."
kubectl apply -f fio-benchmark-test.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready --timeout=300s pod -l app=fio-benchmark-web
kubectl wait --for=condition=ready --timeout=300s pod -l app=fio-benchmark

echo ""
echo "📊 Deployment Status:"
kubectl get pods,svc,ds -l app=fio-benchmark
kubectl get pods,svc -l app=fio-benchmark-web

echo ""
echo "🎯 FIO Benchmark Pods:"
FIO_PODS=$(kubectl get pods -l app=fio-benchmark -o jsonpath='{.items[*].metadata.name}')
for pod in $FIO_PODS; do
    NODE=$(kubectl get pod $pod -o jsonpath='{.spec.nodeName}')
    echo "   Pod: $pod on Node: $NODE"
done

echo ""
echo "🌐 Access Information:"
echo "======================================"

# Hardcoded node IPs
NODE_IPS="10.14.100.2 10.14.100.3"
NODEPORT=$(kubectl get svc fio-benchmark-web-service -o jsonpath='{.spec.ports[0].nodePort}')

echo "🌐 FIO Benchmark Dashboard:"
for ip in $NODE_IPS; do
    echo "   http://$ip:$NODEPORT"
done

echo ""
echo "🏠 Local Access (add to /etc/hosts):"
for ip in $NODE_IPS; do
    echo "   $ip fio-benchmark.local disk-test.local"
done
echo "   Then access: http://fio-benchmark.local:$NODEPORT"

echo ""
echo "🔬 Manual Benchmark Execution:"
echo "======================================"

FIO_PODS=$(kubectl get pods -l app=fio-benchmark -o jsonpath='{.items[*].metadata.name}')
for pod in $FIO_PODS; do
    NODE=$(kubectl get pod $pod -o jsonpath='{.spec.nodeName}')
    echo "Run benchmarks on $NODE:"
    echo "   kubectl exec -it $pod -- /tmp/run-benchmarks.sh"
    echo ""
done

echo "📋 Useful Commands:"
echo "======================================"
echo "🔍 Check FIO pod logs:"
echo "   kubectl logs -l app=fio-benchmark"
echo ""
echo "📊 Run benchmarks on all GPU nodes:"
echo "   for pod in \$(kubectl get pods -l app=fio-benchmark -o name); do"
echo "     echo \"Running benchmark on \$pod...\""
echo "     kubectl exec \$pod -- /tmp/run-benchmarks.sh"
echo "   done"
echo ""
echo "� Run benchmarks with custom size:"
echo "   kubectl exec <pod-name> -- /tmp/run-benchmarks.sh --size 2G"
echo "   kubectl exec <pod-name> -- /tmp/run-benchmarks.sh --size 0.5G --runtime 60"
echo ""
echo "�📈 View benchmark results:"
echo "   kubectl exec <pod-name> -- cat /tmp/fio-test/summary_report.json"
echo ""
echo "🧹 Cleanup when done:"
echo "   kubectl delete -f fio-benchmark-test.yaml"

echo ""
echo "✅ FIO Benchmark Deployment Complete!"
echo ""
echo "🎯 What This Tests:"
echo "   ✅ Sequential Read/Write Performance (MB/s)"
echo "   ✅ Random 4K Read/Write IOPS"
echo "   ✅ Mixed Workload Performance"
echo "   ✅ Storage Latency Measurements"
echo "   ✅ Cross-node Performance Comparison"
echo ""
echo "⚙️ Test Size Options:"
echo "   📏 Default: 0.5GB (fast, good for quick tests)"
echo "   📏 Standard: 1GB (balanced speed vs accuracy)"
echo "   📏 Thorough: 2GB+ (more accurate, longer runtime)"
echo "   📏 Custom: Use web dashboard or --size parameter"
echo ""
echo "🚀 Access the web dashboard to start benchmarks!"
echo "   Dashboard provides real-time results and comparison"
