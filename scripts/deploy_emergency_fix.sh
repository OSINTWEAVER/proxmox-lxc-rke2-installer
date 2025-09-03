#!/bin/bash
# Deploy and run emergency helm fix on multiple RKE2 clusters
# Usage: ./deploy_emergency_fix.sh [octostar|iris|both]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to deploy and run fix on a cluster
deploy_fix() {
    local cluster_name=$1
    local inventory_file=$2
    
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}🚀 DEPLOYING FIX TO $cluster_name CLUSTER${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    # Copy emergency fix script to all nodes
    echo "Copying emergency fix script to cluster nodes..."
    ansible -i "$inventory_file" all -m copy \
        -a "src=$SCRIPT_DIR/emergency_helm_fix.sh dest=/tmp/emergency_helm_fix.sh mode=0755" \
        --become
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy script to $cluster_name cluster${NC}"
        return 1
    fi
    
    # Run on server nodes first
    echo -e "${YELLOW}Running emergency fix on $cluster_name server nodes...${NC}"
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "/tmp/emergency_helm_fix.sh" \
        --become
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Emergency fix completed on $cluster_name server nodes${NC}"
    else
        echo -e "${RED}✗ Emergency fix failed on $cluster_name server nodes${NC}"
        return 1
    fi
    
    # Wait a bit for cluster to stabilize
    echo "Waiting 30 seconds for cluster to stabilize..."
    sleep 30
    
    # Verify fix on server node
    echo "Verifying fix on $cluster_name cluster..."
    ansible -i "$inventory_file" rke2_servers -m shell \
        -a "kubectl get pods -n cattle-system -l job-name --no-headers | wc -l" \
        --become
    
    echo -e "${GREEN}✓ $cluster_name cluster fix deployment complete${NC}"
    echo ""
}

# Main execution
case "${1:-both}" in
    "octostar")
        deploy_fix "OCTOSTAR" "$PROJECT_ROOT/inventories/hosts-octostar_actual.ini"
        ;;
    "iris")
        deploy_fix "IRIS" "$PROJECT_ROOT/inventories/hosts-iris.ini"
        ;;
    "both")
        echo -e "${BLUE}🚀 DEPLOYING EMERGENCY FIX TO BOTH CLUSTERS${NC}"
        echo ""
        
        deploy_fix "OCTOSTAR" "$PROJECT_ROOT/inventories/hosts-octostar_actual.ini"
        echo ""
        deploy_fix "IRIS" "$PROJECT_ROOT/inventories/hosts-iris.ini"
        ;;
    *)
        echo "Usage: $0 [octostar|iris|both]"
        echo ""
        echo "Examples:"
        echo "  $0 octostar    # Fix only octostar cluster"
        echo "  $0 iris        # Fix only iris cluster" 
        echo "  $0 both        # Fix both clusters (default)"
        exit 1
        ;;
esac

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}🎉 EMERGENCY FIX DEPLOYMENT COMPLETE${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Monitor cluster status with:"
echo "  # Octostar cluster:"
echo "  kubectl --kubeconfig kubeconfig/octostar/hosts.yaml get pods -n cattle-system -l job-name"
echo ""
echo "  # Iris cluster:"
echo "  kubectl --kubeconfig kubeconfig/iris/iris-kubeconfig.yaml get pods -n cattle-system -l job-name"
echo ""
echo "If issues persist, check individual cluster logs:"
echo "  ansible -i inventories/hosts-octostar_actual.ini rke2_servers -m shell -a 'journalctl -u rke2-server -n 50' --become"
echo "  ansible -i inventories/hosts-iris.ini rke2_servers -m shell -a 'journalctl -u rke2-server -n 50' --become"
