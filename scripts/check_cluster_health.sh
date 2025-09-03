#!/bin/bash
# Quick cluster health check for both RKE2 clusters
# Usage: ./check_cluster_health.sh [octostar|iris|both]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_cluster() {
    local cluster_name=$1
    local inventory_file=$2
    
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}🔍 CHECKING $cluster_name CLUSTER HEALTH${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    echo "1. Cluster nodes status:"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get nodes -o wide" \
        --become | grep -v "CHANGED"
    
    echo ""
    echo "2. Helm operations count:"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get pods -n cattle-system -l job-name --no-headers | wc -l" \
        --become | grep -v "CHANGED"
    
    echo ""
    echo "3. Recent helm operations:"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get pods -n cattle-system -l job-name --sort-by=.metadata.creationTimestamp | tail -5" \
        --become | grep -v "CHANGED"
    
    echo ""
    echo "4. CoreDNS status:"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get pods -n kube-system -l k8s-app=kube-dns" \
        --become | grep -v "CHANGED"
    
    echo ""
    echo "5. DNS resolution test:"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl run dns-test-$cluster_name --image=busybox --rm -it --restart=Never --timeout=10s -- nslookup kubernetes.default 2>/dev/null || echo 'DNS test failed'" \
        --become | grep -v "CHANGED"
    
    echo -e "${GREEN}✓ $cluster_name health check complete${NC}"
    echo ""
}

# Main execution
case "${1:-both}" in
    "octostar")
        check_cluster "OCTOSTAR" "$PROJECT_ROOT/inventories/hosts-octostar_actual.ini"
        ;;
    "iris")
        check_cluster "IRIS" "$PROJECT_ROOT/inventories/hosts-iris.ini"
        ;;
    "both")
        check_cluster "OCTOSTAR" "$PROJECT_ROOT/inventories/hosts-octostar_actual.ini"
        check_cluster "IRIS" "$PROJECT_ROOT/inventories/hosts-iris.ini"
        ;;
    *)
        echo "Usage: $0 [octostar|iris|both]"
        exit 1
        ;;
esac

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}🎉 HEALTH CHECK COMPLETE${NC}"
echo -e "${BLUE}======================================${NC}"
