#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided. Usage: deploy.sh <inventory>"
    exit 1
fi

set -e

INVENTORY="${SCRIPT_DIR}/inventories/${1}"

if [ ! -f "${INVENTORY}" ]
then
    echo "${INVENTORY} does not exist, exiting"
    exit 1
else
    echo "Using inventory ${INVENTORY}..."
fi

# Function to clean up any broken previous installs
cleanup_previous_installs() {
    echo "=== Cleaning up any previous installations ==="
    
    # Read IPs from inventory file
    local ips=$(grep -E "^[0-9]" "${INVENTORY}" | awk '{print $1}' | head -10)
    
    if [ -z "$ips" ]; then
        echo "No IPs found in inventory, skipping cleanup"
        return
    fi
    
    for ip in $ips; do
        echo "  Cleaning up node $ip..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 adm4n@$ip "
            sudo systemctl stop rke2-server rke2-agent 2>/dev/null || true
            sudo systemctl disable rke2-server rke2-agent 2>/dev/null || true
            sudo pkill -9 -f rke2 2>/dev/null || true
            sudo pkill -9 -f containerd 2>/dev/null || true
            sudo rm -rf /var/lib/rancher/rke2/server/db /var/lib/rancher/rke2/server/tls /var/lib/rancher/rke2/agent 2>/dev/null || true
            sudo rm -f /etc/rancher/rke2/config.yaml 2>/dev/null || true
        " 2>/dev/null &
    done
    wait
    echo "  ✓ Cleanup complete"
}

# Function to setup local role with LXC fixes
setup_local_role() {
    echo "=== Setting up local ansible-role-rke2 with LXC fixes ==="
    
    # Remove any existing local role
    rm -rf "${SCRIPT_DIR}/roles/rke2" 2>/dev/null || true
    
    # Use existing ansible-role-rke2 directory (transferred from Windows)
    if [ ! -d "${SCRIPT_DIR}/ansible-role-rke2" ]; then
        echo "  ERROR: ansible-role-rke2 directory not found!"
        echo "  Please ensure the role was transferred from Windows."
        exit 1
    else
        echo "  Using transferred ansible-role-rke2..."
    fi
    
    # Copy to roles directory
    mkdir -p "${SCRIPT_DIR}/roles"
    cp -r "${SCRIPT_DIR}/ansible-role-rke2" "${SCRIPT_DIR}/roles/rke2"
    echo "  ✓ Copied ansible-role-rke2 to roles/rke2"
    
    # Group names are already fixed in the transferred role defaults
    echo "  ✓ Group names: rke2_servers_group_name and rke2_agents_group_name are correctly set"
    
    # Update ansible.cfg to use local roles
    if ! grep -q "roles_path" ansible.cfg 2>/dev/null; then
        echo "" >> ansible.cfg
        echo "[defaults]" >> ansible.cfg
        echo "roles_path = ./roles" >> ansible.cfg
        echo "  ✓ Updated ansible.cfg to use local roles"
    fi
    
    echo "  ✓ Local role setup complete"
}

# Function to verify setup
verify_setup() {
    echo "=== Verifying setup ==="
    
    if [ -f "${SCRIPT_DIR}/roles/rke2/defaults/main.yml" ]; then
        if grep -q "rke2_servers_group_name: rke2_servers" "${SCRIPT_DIR}/roles/rke2/defaults/main.yml"; then
            echo "  ✓ Group name fix verified (rke2_servers)"
        else
            echo "  ✗ Group name fix failed"
            return 1
        fi
        
        if grep -q "rke2_agents_group_name: rke2_agents" "${SCRIPT_DIR}/roles/rke2/defaults/main.yml"; then
            echo "  ✓ Group name fix verified (rke2_agents)"
        else
            echo "  ✗ Group name fix failed"
            return 1
        fi
    else
        echo "  ✗ Role not properly copied"
        return 1
    fi
    
    echo "  ✓ All verifications passed"
}

# Main execution
echo "=== RKE2 Installer - Robust Deployment ==="

# Always clean up and setup fresh to ensure consistency
cleanup_previous_installs
setup_local_role
verify_setup

echo "=== Starting deployment ==="
ansible-playbook "playbooks/playbook.yml" -i "${INVENTORY}" --ask-become-pass

echo "=== Deployment completed successfully! ==="