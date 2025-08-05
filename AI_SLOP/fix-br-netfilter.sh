#!/bin/bash
# br_netfilter LXC troubleshooting script
# Run this on your Proxmox host to diagnose and fix the br_netfilter issue

echo "🔍 Proxmox Host br_netfilter Diagnosis"
echo "====================================="

echo
echo "1. Checking current kernel modules..."
echo "Current loaded modules related to netfilter:"
lsmod | grep -E "(br_netfilter|bridge|netfilter)" | head -10

echo
echo "2. Checking available modules..."
echo "Available netfilter modules:"
find /lib/modules/$(uname -r) -name "*netfilter*" -o -name "*bridge*" | grep -E "(br_netfilter|bridge)" | head -5

echo
echo "3. Attempting to load br_netfilter..."
if modprobe br_netfilter 2>/dev/null; then
    echo "✅ Successfully loaded br_netfilter"
else
    echo "❌ Failed to load br_netfilter"
    echo "Checking if it's built into kernel..."
    if grep -q br_netfilter /proc/modules 2>/dev/null; then
        echo "✅ br_netfilter is already loaded"
    elif zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_BRIDGE_NETFILTER=y"; then
        echo "ℹ️ br_netfilter is built into kernel (not as module)"
    elif [ -f /boot/config-$(uname -r) ] && grep -q "CONFIG_BRIDGE_NETFILTER=y" /boot/config-$(uname -r); then
        echo "ℹ️ br_netfilter is built into kernel (not as module)"
    else
        echo "⚠️ br_netfilter may not be available"
    fi
fi

echo
echo "4. Checking bridge kernel config..."
if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    echo "✅ Bridge netfilter is available"
    echo "Current bridge-nf-call-iptables: $(cat /proc/sys/net/bridge/bridge-nf-call-iptables)"
    echo "Current bridge-nf-call-ip6tables: $(cat /proc/sys/net/bridge/bridge-nf-call-ip6tables 2>/dev/null || echo 'N/A')"
else
    echo "❌ Bridge netfilter sysctls not available"
fi

echo
echo "5. Testing manual module loading alternatives..."

# Try alternative module names
for module in br_netfilter bridge netfilter_conntrack; do
    echo -n "Testing $module: "
    if modprobe $module 2>/dev/null; then
        echo "✅ Loaded"
    else
        echo "❌ Failed"
    fi
done

echo
echo "6. Final status check..."
if lsmod | grep -q br_netfilter; then
    echo "✅ br_netfilter is now loaded"
elif [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    echo "✅ Bridge netfilter functionality is available (built-in)"
else
    echo "⚠️ br_netfilter functionality may be limited"
fi

echo
echo "7. Making persistent..."
if ! grep -q "br_netfilter" /etc/modules-load.d/k8s.conf 2>/dev/null; then
    echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
    echo "✅ Added br_netfilter to /etc/modules-load.d/k8s.conf"
else
    echo "ℹ️ br_netfilter already in /etc/modules-load.d/k8s.conf"
fi

echo
echo "8. Recommendations:"
echo "   - Restart your LXC containers after this"
echo "   - RKE2 should work even if br_netfilter shows as 'not loaded'"
echo "   - Monitor network connectivity after cluster starts"

echo
echo "🏁 Diagnosis complete!"
