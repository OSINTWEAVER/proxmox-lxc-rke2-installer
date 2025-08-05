#!/bin/bash
# Enable bridge netfilter on Proxmox host
# Run this on your Proxmox host to complete the br_netfilter setup

echo "🔧 Enabling bridge netfilter sysctls on Proxmox host"
echo "=================================================="

echo "Current settings:"
echo "bridge-nf-call-iptables: $(cat /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || echo 'N/A')"
echo "bridge-nf-call-ip6tables: $(cat /proc/sys/net/bridge/bridge-nf-call-ip6tables 2>/dev/null || echo 'N/A')"

echo
echo "Enabling bridge netfilter..."
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables

echo
echo "Making persistent..."
cat > /etc/sysctl.d/k8s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

echo "✅ Bridge netfilter enabled and made persistent"
echo
echo "New settings:"
echo "bridge-nf-call-iptables: $(cat /proc/sys/net/bridge/bridge-nf-call-iptables)"
echo "bridge-nf-call-ip6tables: $(cat /proc/sys/net/bridge/bridge-nf-call-ip6tables)"

echo
echo "🏁 Complete! Your LXC containers should now have proper bridge netfilter support."
