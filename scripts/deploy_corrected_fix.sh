#!/bin/bash

# Deploy corrected emergency fix for helm operation loops
# This version uses the correct service CIDR DNS IPs

set -e

CLUSTER_TARGET="$1"

if [ -z "$CLUSTER_TARGET" ]; then
    echo "Usage: $0 {octostar|iris|both}"
    echo "  octostar - Deploy to Octostar cluster only"
    echo "  iris     - Deploy to Iris cluster only" 
    echo "  both     - Deploy to both clusters"
    exit 1
fi

deploy_to_cluster() {
    local cluster_name="$1"
    local inventory_file="$2"
    
    echo "======================================"
    echo "🚀 DEPLOYING CORRECTED FIX TO ${cluster_name^^} CLUSTER"
    echo "======================================"
    
    # Copy the corrected emergency fix script to cluster nodes
    echo "Copying corrected emergency fix script to cluster nodes..."
    ansible -i "$inventory_file" all -m copy \
        -a "src=scripts/emergency_helm_fix_corrected.sh dest=/tmp/emergency_helm_fix_corrected.sh mode=0755" \
        --become
    
    # Run the corrected fix on server nodes only (they have kubectl access)
    echo "Running corrected emergency fix on ${cluster_name^^} server nodes..."
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "/tmp/emergency_helm_fix_corrected.sh" \
        --become
    
    echo "✓ Emergency fix completed on ${cluster_name^^} server nodes"
    
    # Wait for cluster to stabilize
    echo "Waiting 30 seconds for cluster to stabilize..."
    sleep 30
    
    # Verify the fix worked
    echo "Verifying fix on ${cluster_name^^} cluster..."
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get pods -n cattle-system -l job-name 2>/dev/null | grep -v NAME | wc -l || echo '0'" \
        --become
    
    echo "✓ ${cluster_name^^} cluster fix deployment complete"
    echo ""
}

case "$CLUSTER_TARGET" in
    "octostar")
        deploy_to_cluster "octostar" "inventories/hosts-octostar_actual.ini"
        ;;
    "iris")
        deploy_to_cluster "iris" "inventories/hosts-iris.ini"
        ;;
    "both")
        deploy_to_cluster "octostar" "inventories/hosts-octostar_actual.ini"
        deploy_to_cluster "iris" "inventories/hosts-iris.ini"
        ;;
    *)
        echo "❌ Invalid target: $CLUSTER_TARGET"
        echo "Valid targets: octostar, iris, both"
        exit 1
        ;;
esac

echo "======================================"
echo "🎉 CORRECTED EMERGENCY FIX DEPLOYMENT COMPLETE"
echo "======================================"
echo ""
echo "Monitor cluster status with:"

if [ "$CLUSTER_TARGET" = "octostar" ] || [ "$CLUSTER_TARGET" = "both" ]; then
    echo "  # Octostar cluster:"
    echo "  kubectl --kubeconfig kubeconfig/octostar/hosts.yaml get pods -n cattle-system -l job-name"
fi

if [ "$CLUSTER_TARGET" = "iris" ] || [ "$CLUSTER_TARGET" = "both" ]; then
    echo "  # Iris cluster:"
    echo "  kubectl --kubeconfig kubeconfig/iris/iris-kubeconfig.yaml get pods -n cattle-system -l job-name"
fi

echo ""
echo "Test DNS resolution:"
if [ "$CLUSTER_TARGET" = "octostar" ] || [ "$CLUSTER_TARGET" = "both" ]; then
    echo "  ansible -i inventories/hosts-octostar_actual.ini rke2_servers -m shell -a 'nslookup kubernetes.default 10.43.0.10' --become"
fi

if [ "$CLUSTER_TARGET" = "iris" ] || [ "$CLUSTER_TARGET" = "both" ]; then
    echo "  ansible -i inventories/hosts-iris.ini rke2_servers -m shell -a 'nslookup kubernetes.default 10.41.0.10' --become"
fi

echo ""
echo "If issues persist, check individual cluster logs:"
echo "  ansible -i inventories/hosts-octostar_actual.ini rke2_servers -m shell -a 'journalctl -u rke2-server -n 50' --become"
echo "  ansible -i inventories/hosts-iris.ini rke2_servers -m shell -a 'journalctl -u rke2-server -n 50' --become"
