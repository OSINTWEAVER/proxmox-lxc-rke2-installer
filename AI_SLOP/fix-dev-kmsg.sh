#!/bin/bash
# Fix missing /dev/kmsg in LXC container

echo "🔧 FIXING /dev/kmsg FOR LXC KUBELET"
echo "=================================="

# Stop RKE2 first
systemctl stop rke2-server.service || true
sleep 3

# Create /dev/kmsg if it doesn't exist
if [ ! -e /dev/kmsg ]; then
    echo "1. Creating missing /dev/kmsg device..."
    # Create a dummy kmsg device (points to /dev/null for LXC)
    ln -sf /dev/null /dev/kmsg
    echo "✅ Created /dev/kmsg -> /dev/null"
else
    echo "✅ /dev/kmsg already exists"
fi

# Make sure it persists across reboots
echo "2. Making /dev/kmsg persistent..."
echo 'ln -sf /dev/null /dev/kmsg 2>/dev/null || true' >> /etc/rc.local
chmod +x /etc/rc.local 2>/dev/null || true

# Also create a systemd service to ensure it's always there
cat > /etc/systemd/system/create-kmsg.service << 'EOF'
[Unit]
Description=Create /dev/kmsg for LXC containers
DefaultDependencies=false
Before=rke2-server.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'ln -sf /dev/null /dev/kmsg 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable create-kmsg.service
systemctl start create-kmsg.service

echo "3. Restarting RKE2..."
systemctl start rke2-server.service

echo "✅ /dev/kmsg FIX APPLIED!"
echo "Monitor with: journalctl -u rke2-server.service -f"
