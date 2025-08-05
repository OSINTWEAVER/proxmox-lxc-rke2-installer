#!/bin/bash
# ULTIMATE SIMPLE RKE2 TEST - No wrappers, just basic RKE2
set -e

echo "🎯 ULTIMATE SIMPLE RKE2 TEST"
echo "==========================="

# Clean stop
echo "1. Stopping everything..."
systemctl stop rke2-server || true
pkill -f rke2 || true
sleep 3

# Minimal cleanup
echo "2. Minimal cleanup..."
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /etc/systemd/system/rke2-server.service.d

echo "3. Installing RKE2..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "4. Creating absolute minimal config..."
mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml << 'EOF'
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
EOF

echo "5. Starting RKE2 with NO modifications..."
systemctl daemon-reload
systemctl start rke2-server

echo ""
echo "✅ STARTED RKE2 WITH ZERO MODIFICATIONS"
echo "======================================"
echo "Let's see what the exact kubelet error is without any wrappers."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
