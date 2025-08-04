#!/bin/bash
# Quick validation script for the Ansible LXC fixes
# This should be run before deploying to verify the role is properly configured

echo "🔧 ANSIBLE ROLE VALIDATION"
echo "========================="

role_path="ansible-role-rke2"
if [ ! -d "$role_path" ]; then
    echo "❌ ERROR: ansible-role-rke2 directory not found"
    echo "   Run this script from the root of the repository"
    exit 1
fi

echo "1. Checking for kubelet config file prevention..."

# Check if the fixes prevent kubelet config creation
if grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/first_server.yml"; then
    echo "✅ first_server.yml: kubelet config disabled for LXC"
else
    echo "❌ first_server.yml: Missing LXC conditional for kubelet config"
fi

if grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/remaining_nodes.yml"; then
    echo "✅ remaining_nodes.yml: kubelet config disabled for LXC"
else
    echo "❌ remaining_nodes.yml: Missing LXC conditional for kubelet config"
fi

if grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/standalone.yml"; then
    echo "✅ standalone.yml: kubelet config disabled for LXC"
else
    echo "❌ standalone.yml: Missing LXC conditional for kubelet config"
fi

echo ""
echo "2. Checking directory creation in LXC fixes..."

if grep -q "path: /etc/rancher/rke2" "$role_path/tasks/lxc_fixes.yml"; then
    echo "✅ lxc_fixes.yml: Creates /etc/rancher/rke2 directory"
else
    echo "❌ lxc_fixes.yml: Missing directory creation"
fi

echo ""
echo "3. Checking for problematic kubelet-config-file references..."

config_refs=$(grep -r "kubelet-config-file" "$role_path" --exclude-dir=.git | grep -v "# CRITICAL: No kubelet-config-file" | wc -l)
if [ "$config_refs" -eq 0 ]; then
    echo "✅ No problematic kubelet-config-file references found"
else
    echo "❌ Found $config_refs kubelet-config-file references:"
    grep -r "kubelet-config-file" "$role_path" --exclude-dir=.git | grep -v "# CRITICAL: No kubelet-config-file"
fi

echo ""
echo "4. Checking LXC-specific configuration..."

if grep -q "protect-kernel-defaults=false" "$role_path/defaults/lxc_overrides.yml"; then
    echo "✅ LXC overrides: protect-kernel-defaults=false configured"
else
    echo "❌ LXC overrides: Missing protect-kernel-defaults=false"
fi

if grep -q "fail-swap-on=false" "$role_path/templates/config.yaml.j2"; then
    echo "✅ Config template: fail-swap-on=false for LXC"
else
    echo "❌ Config template: Missing fail-swap-on=false"
fi

echo ""
echo "5. Checking diagnostic scripts..."

diag_dir="diagnostic_scripts"
if [ -f "$diag_dir/analyze-kubelet-config.sh" ]; then
    echo "✅ Kubelet config analyzer available"
else
    echo "⚠️  Kubelet config analyzer missing"
fi

if [ -f "$diag_dir/monitor-rke2-startup.sh" ]; then
    echo "✅ RKE2 startup monitor available"
else
    echo "⚠️  RKE2 startup monitor missing"
fi

# Check that emergency fix scripts are removed (Ansible-only approach)
emergency_scripts=$(find "$diag_dir" -name "fix-*.sh" 2>/dev/null | wc -l)
if [ "$emergency_scripts" -eq 0 ]; then
    echo "✅ No emergency fix scripts found (Ansible-only approach)"
else
    echo "⚠️  Found $emergency_scripts emergency fix scripts - should use Ansible only"
fi

echo ""
echo "🏁 VALIDATION COMPLETE"
echo "====================="

# Count issues
issues=0
if ! grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/first_server.yml"; then
    issues=$((issues + 1))
fi
if ! grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/remaining_nodes.yml"; then
    issues=$((issues + 1))
fi
if ! grep -q "when: not (is_lxc_container | default(false))" "$role_path/tasks/standalone.yml"; then
    issues=$((issues + 1))
fi
if ! grep -q "path: /etc/rancher/rke2" "$role_path/tasks/lxc_fixes.yml"; then
    issues=$((issues + 1))
fi
if [ "$config_refs" -gt 0 ]; then
    issues=$((issues + 1))
fi

if [ "$issues" -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED - Ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Run: ansible-playbook playbooks/playbook.yml -i inventories/hosts.ini"
    echo "2. Monitor with: diagnostic_scripts/monitor-rke2-startup.sh"
    echo "3. If issues arise, run: diagnostic_scripts/analyze-kubelet-config.sh"
else
    echo "❌ $issues ISSUES FOUND - Fix before deployment"
    exit 1
fi
