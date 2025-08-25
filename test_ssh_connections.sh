#!/bin/bash
# SSH Connection Quality Test for LXC Deployment
# This script tests SSH connectivity and network quality to all target hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 SSH Connection Quality Test for LXC Deployment${NC}"
echo "=================================================="

# Function to test SSH connectivity
test_ssh_connection() {
    local host=$1
    local user=${2:-root}
    local timeout=${3:-10}
    
    echo -n "Testing SSH to $user@$host: "
    
    if timeout $timeout ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$host" 'echo "SSH_OK"' 2>/dev/null | grep -q "SSH_OK"; then
        echo -e "${GREEN}✅ Connected${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Function to test network latency
test_network_latency() {
    local host=$1
    echo -n "Testing latency to $host: "
    
    if command -v ping &> /dev/null; then
        local latency=$(ping -c 3 -W 2 "$host" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || echo "failed")
        if [ "$latency" != "failed" ] && [ ! -z "$latency" ]; then
            if (( $(echo "$latency < 50" | bc -l) )); then
                echo -e "${GREEN}✅ ${latency}ms (excellent)${NC}"
            elif (( $(echo "$latency < 100" | bc -l) )); then
                echo -e "${YELLOW}⚠️  ${latency}ms (good)${NC}"
            else
                echo -e "${RED}⚠️  ${latency}ms (high latency)${NC}"
            fi
        else
            echo -e "${RED}❌ No response${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  ping not available${NC}"
    fi
}

# Function to extract hosts from inventory
get_hosts_from_inventory() {
    local inventory_file=$1
    
    if [ ! -f "$inventory_file" ]; then
        echo -e "${RED}❌ Inventory file not found: $inventory_file${NC}"
        return 1
    fi
    
    # Extract IP addresses from inventory file (basic parsing)
    grep -E "^[0-9]" "$inventory_file" | awk '{print $1}' || true
}

# Main execution
echo -e "\n${BLUE}📋 Reading inventory files...${NC}"

# Check for inventory files
PROXMOX_INVENTORY="inventories/hosts_proxmox.ini"
MAIN_INVENTORY="inventories/hosts.ini"

if [ -f "$PROXMOX_INVENTORY" ]; then
    echo -e "\n${BLUE}🖥️  Testing Proxmox hosts connectivity:${NC}"
    PROXMOX_HOSTS=$(get_hosts_from_inventory "$PROXMOX_INVENTORY")
    
    if [ ! -z "$PROXMOX_HOSTS" ]; then
        for host in $PROXMOX_HOSTS; do
            test_network_latency "$host"
            test_ssh_connection "$host" "root"
        done
    else
        echo -e "${YELLOW}⚠️  No Proxmox hosts found in $PROXMOX_INVENTORY${NC}"
    fi
fi

if [ -f "$MAIN_INVENTORY" ]; then
    echo -e "\n${BLUE}🐳 Testing LXC container connectivity:${NC}"
    LXC_HOSTS=$(get_hosts_from_inventory "$MAIN_INVENTORY")
    
    if [ ! -z "$LXC_HOSTS" ]; then
        for host in $LXC_HOSTS; do
            test_network_latency "$host"
            test_ssh_connection "$host" "root"
            test_ssh_connection "$host" "adm4n"  # Test both users
        done
    else
        echo -e "${YELLOW}⚠️  No LXC hosts found in $MAIN_INVENTORY${NC}"
    fi
fi

# Test SSH control path functionality
echo -e "\n${BLUE}🔧 Testing SSH connection multiplexing:${NC}"
CONTROL_PATH_DIR="/tmp/.ansible-cp"
if [ -d "$CONTROL_PATH_DIR" ]; then
    echo -e "Control path directory exists: ${GREEN}✅${NC}"
    echo "Active control connections: $(ls -1 $CONTROL_PATH_DIR 2>/dev/null | wc -l)"
else
    echo -e "Creating control path directory: ${YELLOW}⚠️${NC}"
    mkdir -p "$CONTROL_PATH_DIR"
fi

# Test Ansible connectivity
echo -e "\n${BLUE}🤖 Testing Ansible connectivity:${NC}"
if command -v ansible &> /dev/null; then
    echo -n "Testing Ansible ping to all hosts: "
    if ansible all -i inventories/hosts.ini -m ping -o 2>/dev/null | grep -q "SUCCESS"; then
        echo -e "${GREEN}✅ Ansible connectivity OK${NC}"
    else
        echo -e "${RED}❌ Ansible connectivity failed${NC}"
        echo "Run with verbose mode: ansible all -i inventories/hosts.ini -m ping -vvv"
    fi
else
    echo -e "${YELLOW}⚠️  Ansible not available in current shell${NC}"
fi

# Network optimization suggestions
echo -e "\n${BLUE}🚀 Network Optimization Recommendations:${NC}"
echo "1. Ensure SSH key authentication is set up (run trust_ssh_hosts.sh)"
echo "2. Consider using SSH connection multiplexing (already configured in ansible.cfg)"
echo "3. For poor connections, reduce ansible forks: export ANSIBLE_FORKS=3"
echo "4. Enable verbose logging for troubleshooting: ansible-playbook -vvv"
echo "5. Use retry files for failed hosts: --limit @playbook.retry"

echo -e "\n${BLUE}📊 Connection Test Complete!${NC}"
echo "If you see connection failures, check the SSH_CONNECTION_RESILIENCE_GUIDE.md for troubleshooting."
