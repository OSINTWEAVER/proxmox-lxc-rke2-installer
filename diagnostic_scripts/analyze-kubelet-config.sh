#!/bin/bash
# Kubelet Configuration Analyzer for LXC
# Analyzes kubelet configuration issues and provides specific recommendations

echo "🔍 KUBELET CONFIGURATION ANALYZER"
echo "================================="

echo "1. Checking kubelet config files..."
echo ""

# Check for problematic kubelet config files
if [ -f /var/lib/kubelet/config.yaml ]; then
    size=$(wc -c < /var/lib/kubelet/config.yaml)
    echo "❌ PROBLEM: /var/lib/kubelet/config.yaml exists ($size bytes)"
    
    if [ "$size" -eq 0 ]; then
        echo "   CRITICAL: File is empty - this causes kubelet crashes"
    else
        echo "   File contents:"
        echo "   $(head -5 /var/lib/kubelet/config.yaml)"
    fi
else
    echo "✅ GOOD: /var/lib/kubelet/config.yaml does not exist"
fi

if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
    size=$(wc -c < /etc/rancher/rke2/kubelet-config.yaml)
    echo "⚠️  FOUND: /etc/rancher/rke2/kubelet-config.yaml exists ($size bytes)"
    
    if [ "$size" -eq 0 ]; then
        echo "   WARNING: File is empty"
    else
        echo "   File appears to have content - this may conflict with LXC fixes"
    fi
else
    echo "✅ GOOD: /etc/rancher/rke2/kubelet-config.yaml does not exist"
fi

echo ""
echo "2. Checking RKE2 configuration..."

if [ -f /etc/rancher/rke2/config.yaml ]; then
    echo "✅ RKE2 config exists"
    
    echo "   Checking for kubelet-config-file reference..."
    if grep -q "kubelet-config-file" /etc/rancher/rke2/config.yaml; then
        echo "   ❌ PROBLEM: kubelet-config-file is referenced"
        echo "   Lines mentioning kubelet-config-file:"
        grep -n "kubelet-config-file" /etc/rancher/rke2/config.yaml | head -3
    else
        echo "   ✅ GOOD: No kubelet-config-file reference found"
    fi
    
    echo "   Checking for critical LXC kubelet arguments..."
    local critical_args=("protect-kernel-defaults=false" "fail-swap-on=false" "container-runtime-endpoint")
    for arg in "${critical_args[@]}"; do
        if grep -q "$arg" /etc/rancher/rke2/config.yaml; then
            echo "   ✅ FOUND: $arg"
        else
            echo "   ❌ MISSING: $arg"
        fi
    done
    
else
    echo "❌ CRITICAL: /etc/rancher/rke2/config.yaml does not exist"
fi

echo ""
echo "3. Testing kernel parameter access (LXC compatibility)..."

declare -a KERNEL_PARAMS=(
    "vm/overcommit_memory"
    "kernel/panic"
    "kernel/panic_on_oops"
    "net/ipv4/ip_forward"
)

readonly_count=0
for param in "${KERNEL_PARAMS[@]}"; do
    param_path="/proc/sys/$param"
    if [ -f "$param_path" ]; then
        current_value=$(cat "$param_path")
        echo -n "   $param (current: $current_value): "
        
        if echo "$current_value" > "$param_path" 2>/dev/null; then
            echo "WRITABLE ✅"
        else
            echo "READ-ONLY ❌"
            readonly_count=$((readonly_count + 1))
        fi
    else
        echo "   $param: NOT ACCESSIBLE ❌"
        readonly_count=$((readonly_count + 1))
    fi
done

if [ "$readonly_count" -gt 0 ]; then
    echo ""
    echo "   ⚠️  $readonly_count kernel parameters are read-only"
    echo "   This is NORMAL for LXC containers and requires protect-kernel-defaults=false"
else
    echo ""
    echo "   ✅ All kernel parameters are writable"
fi

echo ""
echo "4. Checking container runtime (Docker)..."

if systemctl is-active --quiet docker; then
    echo "✅ Docker service is running"
    
    # Check Docker socket
    if [ -S /var/run/docker.sock ]; then
        echo "✅ Docker socket exists: /var/run/docker.sock"
        
        # Try to query Docker
        if timeout 5 docker version >/dev/null 2>&1; then
            echo "✅ Docker is responding"
            echo "   Docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'Unknown')"
        else
            echo "❌ Docker is not responding"
        fi
    else
        echo "❌ CRITICAL: Docker socket missing"
    fi
else
    echo "❌ CRITICAL: Docker service is not running"
fi

# Check for old containerd references
if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo "⚠️  Old containerd socket still exists (may cause conflicts)"
else
    echo "✅ No conflicting containerd socket found"
fi

echo ""
echo "5. Checking recent kubelet errors..."

recent_kubelet_errors=$(journalctl -u rke2-server.service --since "5 minutes ago" | grep -i "kubelet.*error\|kubelet.*failed\|kubelet exited" | wc -l)

if [ "$recent_kubelet_errors" -eq 0 ]; then
    echo "✅ No recent kubelet errors"
else
    echo "❌ Found $recent_kubelet_errors recent kubelet errors"
    echo "   Last 3 kubelet errors:"
    journalctl -u rke2-server.service --since "5 minutes ago" | grep -i "kubelet.*error\|kubelet.*failed\|kubelet exited" | tail -3 | while read line; do
        echo "   $line"
    done
fi

echo ""
echo "6. Checking LXC container environment..."

if grep -qa container=lxc /proc/1/environ 2>/dev/null; then
    echo "✅ Confirmed: Running in LXC container"
else
    echo "⚠️  Not detected as LXC container"
fi

if [ -L /dev/kmsg ]; then
    echo "✅ /dev/kmsg symlink exists: $(readlink /dev/kmsg)"
else
    echo "❌ /dev/kmsg missing or not a symlink"
fi

echo ""
echo "🏁 ANALYSIS COMPLETE"
echo "==================="

# Provide recommendations based on findings
echo ""
echo "RECOMMENDATIONS:"

if [ -f /var/lib/kubelet/config.yaml ]; then
    echo "1. ❌ CRITICAL: Remove /var/lib/kubelet/config.yaml (causes crashes)"
fi

if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
    echo "2. ⚠️  RECOMMENDED: Remove /etc/rancher/rke2/kubelet-config.yaml (may conflict)"
fi

if [ "$readonly_count" -gt 0 ]; then
    echo "3. ✅ VERIFIED: protect-kernel-defaults=false is required (LXC has read-only kernel params)"
fi

if [ "$recent_kubelet_errors" -gt 0 ]; then
    echo "4. 🔧 INVESTIGATE: Recent kubelet errors found - check logs above"
fi

echo ""
echo "For immediate help with kubelet crashes, check the Ansible role fixes:"
echo "- ansible-role-rke2/tasks/lxc_fixes.yml"
echo "- Ensure kubelet config files are disabled for LXC containers"
