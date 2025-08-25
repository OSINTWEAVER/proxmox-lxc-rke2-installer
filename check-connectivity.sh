#!/bin/bash
# SSH Connection Check Script for RKE2 Deployment
# This script verifies SSH connectivity to all nodes before deployment

echo "🔍 Checking SSH connectivity to all cluster nodes..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INVENTORY_FILE="${1:-inventories/hosts.ini}"
FAILED_NODES=()
SUCCESS_NODES=()

if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo -e "${RED}❌ Inventory file not found: $INVENTORY_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Using inventory: $INVENTORY_FILE${NC}"
echo ""

# Extract node IPs and users from inventory
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Extract IP and user from lines like: 10.42.30.1 ansible_user=adm4n rke2_type=agent
    if [[ "$line" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+.*ansible_user=([^[:space:]]+) ]]; then
        node_ip="${BASH_REMATCH[1]}"
        node_user="${BASH_REMATCH[2]}"
        
        echo -n "Testing $node_user@$node_ip ... "
        
        # Test SSH connection with timeout
        if timeout 30 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes "$node_user@$node_ip" "echo 'Connected successfully'" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ SUCCESS${NC}"
            SUCCESS_NODES+=("$node_user@$node_ip")
        else
            echo -e "${RED}❌ FAILED${NC}"
            FAILED_NODES+=("$node_user@$node_ip")
        fi
    fi
done < "$INVENTORY_FILE"

echo ""
echo "=================================================="
echo "🎯 Connection Test Results:"
echo "=================================================="

if [[ ${#SUCCESS_NODES[@]} -gt 0 ]]; then
    echo -e "${GREEN}✅ Successful connections (${#SUCCESS_NODES[@]}):"
    for node in "${SUCCESS_NODES[@]}"; do
        echo -e "${GREEN}   ✓ $node${NC}"
    done
    echo ""
fi

if [[ ${#FAILED_NODES[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Failed connections (${#FAILED_NODES[@]}):"
    for node in "${FAILED_NODES[@]}"; do
        echo -e "${RED}   ✗ $node${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting tips for failed connections:${NC}"
    echo "   1. Verify SSH key is added to the target nodes"
    echo "   2. Check if nodes are powered on and network accessible"
    echo "   3. Verify firewall rules allow SSH (port 22)"
    echo "   4. Test manual SSH: ssh -o ConnectTimeout=10 user@ip"
    echo "   5. Check if SSH service is running on target nodes"
    echo ""
    echo -e "${YELLOW}⚠️  Warning: Deployment may fail or be incomplete with unreachable nodes${NC}"
    echo -e "${YELLOW}🔧 Recommendation: Fix connectivity issues before proceeding${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}🎉 All nodes are reachable! Ready for deployment.${NC}"
    echo ""
    echo -e "${GREEN}✅ You can now run: ansible-playbook -i $INVENTORY_FILE playbooks/playbook.yml${NC}"
    echo ""
fi
