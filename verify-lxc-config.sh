#!/bin/bash

# LXC Configuration Verification Script
# Verifies that the RKE2 installer is properly configured for LXC containers

echo "🔍 LXC Compatibility Verification"
echo "=================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

# Function to check file content
check_file_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if [[ -f "$file" ]]; then
        if grep -q "$pattern" "$file"; then
            echo "✅ $description"
        else
            echo "❌ $description"
            ((ERRORS++))
        fi
    else
        echo "❌ File not found: $file"
        ((ERRORS++))
    fi
}

# Function to check directory exists
check_directory() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        echo "✅ $description"
    else
        echo "❌ $description"
        ((ERRORS++))
    fi
}

echo ""
echo "📁 Project Structure"
echo "-------------------"
check_directory "$SCRIPT_DIR/ansible-role-rke2" "Local ansible-role-rke2 directory exists"
check_directory "$SCRIPT_DIR/ansible-role-rke2/defaults" "Role defaults directory exists"
check_directory "$SCRIPT_DIR/ansible-role-rke2/tasks" "Role tasks directory exists"
check_directory "$SCRIPT_DIR/ansible-role-rke2/handlers" "Role handlers directory exists"

echo ""
echo "🔧 Requirements Configuration"
echo "-----------------------------"
check_file_content "$SCRIPT_DIR/requirements.yml" "# Empty requirements list" "External role disabled in requirements.yml"

echo ""
echo "🎛️ Role Configuration"
echo "--------------------"
check_file_content "$SCRIPT_DIR/ansible-role-rke2/defaults/main.yml" "rke2_cni: \[flannel\]" "Flannel CNI configured as default"
check_file_content "$SCRIPT_DIR/ansible-role-rke2/defaults/lxc_overrides.yml" "rke2_lxc_mode: true" "LXC mode enabled in overrides"
check_file_content "$SCRIPT_DIR/ansible-role-rke2/handlers/main.yml" "failed_when: false" "LXC-safe error handling in handlers"

echo ""
echo "🚀 Playbook Configuration"
echo "-------------------------"
check_file_content "$SCRIPT_DIR/playbooks/playbook.yml" "role: rke2" "Playbook references local role correctly"
check_file_content "$SCRIPT_DIR/playbooks/playbook.yml" "rke2_cni:" "CNI configuration present in playbook"
check_file_content "$SCRIPT_DIR/playbooks/playbook.yml" "container_type.stdout" "Container detection logic present"
check_file_content "$SCRIPT_DIR/playbooks/playbook.yml" "--no-kernel-module" "NVIDIA LXC-safe installation configured"

echo ""
echo "📖 Documentation"
echo "----------------"
check_file_content "$SCRIPT_DIR/README.md" "--features nesting=1,keyctl=1" "LXC features documented in README"
check_file_content "$SCRIPT_DIR/README.md" "lxc.apparmor.profile: unconfined" "Security profile configuration documented"
check_file_content "$SCRIPT_DIR/ansible-role-rke2/LXC_DEPLOYMENT_GUIDE.md" "LXC Container Deployment Guide" "LXC deployment guide exists"

echo ""
echo "🎯 Inventory Configuration"
echo "--------------------------"
if [[ -f "$SCRIPT_DIR/inventories/hosts.ini" ]]; then
    check_file_content "$SCRIPT_DIR/inventories/hosts.ini" "rke2_token=" "Security token configured"
    check_file_content "$SCRIPT_DIR/inventories/hosts.ini" "ansible_user=adm4n" "Ansible user configured"
else
    echo "ℹ️  hosts.ini not yet configured (will be created from example)"
fi

echo ""
echo "🔐 Security Configuration"
echo "-------------------------"
check_file_content "$SCRIPT_DIR/ansible-role-rke2/templates/kube-vip/kube-vip.yml.j2" "NET_ADMIN" "kube-vip capabilities configured"
check_file_content "$SCRIPT_DIR/README.md" "lxc.cap.drop:" "Container capabilities documented"

echo ""
echo "🏁 Summary"
echo "=========="
if [[ $ERRORS -eq 0 ]]; then
    echo "🎉 All LXC compatibility checks passed!"
    echo ""
    echo "Your RKE2 installer is properly configured for LXC containers."
    echo "You can proceed with the deployment following the README.md guide."
else
    echo "⚠️  Found $ERRORS issue(s) that need attention."
    echo ""
    echo "Please review the failed checks above before deployment."
fi

echo ""
echo "📋 Next Steps:"
echo "1. Update inventories/hosts.ini with your specific configuration"
echo "2. Follow Part 1-3 of README.md to create and configure LXC containers"
echo "3. Run the deployment with: ./deploy.sh hosts.ini"

exit $ERRORS
