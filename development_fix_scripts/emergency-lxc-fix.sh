#!/bin/bash
# Emergency fix for hanging RKE2 service in LXC containers
# Run this directly in your control-plane container (10.14.100.1)

echo "🚨 Emergency RKE2 LXC Fix Script"
echo "================================"

# Stop the hanging service
echo "1. Stopping hanging RKE2 service..."
systemctl stop rke2-server.service || true
sleep 5

# Kill any remaining processes
echo "2. Cleaning up RKE2 processes..."
pkill -f rke2 || true
pkill -f containerd || true
sleep 3

# Backup original service file
echo "3. Backing up original systemd service..."
cp /usr/local/lib/systemd/system/rke2-server.service /usr/local/lib/systemd/system/rke2-server.service.bak || true

# Create LXC-compatible service file
echo "4. Creating LXC-compatible systemd service..."
cat > /usr/local/lib/systemd/system/rke2-server.service << 'EOF'
[Unit]
Description=Rancher Kubernetes Engine v2 (server) - LXC Compatible
Documentation=https://github.com/rancher/rke2#readme
Wants=network-online.target
After=network-online.target
ConflictsWith=rke2-agent.service

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
# LXC-compatible: Skip kernel module loading (must be done on host)
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service'
# Pre-check that required modules are available (loaded by host)
ExecStartPre=/bin/sh -c 'if [ ! -f /proc/modules ] || ! grep -q br_netfilter /proc/modules; then echo "WARNING: br_netfilter module not loaded on host - continuing anyway"; fi'
ExecStartPre=/bin/sh -c 'if [ ! -f /proc/modules ] || ! grep -q overlay /proc/modules; then echo "WARNING: overlay module not loaded on host - continuing anyway"; fi'
ExecStart=/var/lib/rancher/rke2/bin/rke2 server
ExecStopPost=/bin/sh -c "systemctl kill --kill-who=all --signal=SIGTERM rke2-server.service || true"
KillMode=mixed
Delegate=yes
TimeoutStartSec=300
TimeoutStopSec=120
RestartSec=5
Restart=always
RestartPreventExitStatus=78
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
StandardOutput=journal
StandardError=journal
EnvironmentFile=-/etc/default/rke2-server
EOF

# Reload systemd
echo "5. Reloading systemd daemon..."
systemctl daemon-reload

# Check kernel modules status
echo "6. Checking kernel modules..."
echo "br_netfilter status:"
lsmod | grep br_netfilter || echo "  ❌ NOT LOADED (needs to be loaded on Proxmox host)"
echo "overlay status:"
lsmod | grep overlay || echo "  ❌ NOT LOADED (needs to be loaded on Proxmox host)"

# Start service
echo "7. Starting RKE2 service with LXC compatibility..."
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Monitor startup
echo "8. Monitoring service startup..."
for i in {1..30}; do
    echo "  Attempt $i/30..."
    if systemctl is-active --quiet rke2-server.service; then
        echo "✅ RKE2 service is now active!"
        systemctl status rke2-server.service --no-pager -l
        break
    fi
    sleep 10
    if [ $i -eq 30 ]; then
        echo "❌ Service still not active after 5 minutes"
        echo "Checking status and logs..."
        systemctl status rke2-server.service --no-pager -l
        echo "Recent logs:"
        journalctl -u rke2-server.service --no-pager -n 20
    fi
done

echo
echo "🏁 Emergency fix complete!"
echo "If this worked, you should now see RKE2 continuing with cluster initialization."
echo
echo "⚠️  IMPORTANT: You still need to load kernel modules on your Proxmox host:"
echo "On Proxmox host (not in container), run:"
echo "  modprobe br_netfilter"
echo "  modprobe overlay"
echo "  echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf"
echo "  echo 'overlay' >> /etc/modules-load.d/k8s.conf"
