#!/bin/bash
# Quick fix for RKE2 service executable path
# Run this on your control-plane container (10.14.100.1)

echo "🔧 Quick Fix: RKE2 Service Executable Path"
echo "==========================================="

# Stop the failing service
echo "1. Stopping broken RKE2 service..."
systemctl stop rke2-server.service || true
systemctl reset-failed rke2-server.service || true

# Check where RKE2 binary actually is
echo "2. Finding RKE2 binary location..."
RKE2_BINARY=""
for path in /usr/local/bin/rke2 /opt/rke2/bin/rke2 /var/lib/rancher/rke2/bin/rke2; do
    if [ -f "$path" ]; then
        echo "   Found RKE2 at: $path"
        RKE2_BINARY="$path"
        break
    fi
done

if [ -z "$RKE2_BINARY" ]; then
    echo "❌ ERROR: Could not find RKE2 binary!"
    echo "   Checked:"
    echo "   - /usr/local/bin/rke2"
    echo "   - /opt/rke2/bin/rke2"
    echo "   - /var/lib/rancher/rke2/bin/rke2"
    exit 1
fi

echo "3. Backing up current service file..."
cp /usr/local/lib/systemd/system/rke2-server.service /usr/local/lib/systemd/system/rke2-server.service.backup

echo "4. Creating fixed service file..."
cat > /usr/local/lib/systemd/system/rke2-server.service << EOF
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
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service'
ExecStartPre=/bin/sh -c 'if [ -f /proc/modules ]; then if ! grep -q br_netfilter /proc/modules; then echo "WARNING: br_netfilter module not loaded - continuing anyway"; fi; else echo "WARNING: /proc/modules not available"; fi'
ExecStartPre=/bin/sh -c 'if [ -f /proc/modules ]; then if ! grep -q overlay /proc/modules; then echo "WARNING: overlay module not loaded - continuing anyway"; fi; else echo "WARNING: /proc/modules not available"; fi'
ExecStart=$RKE2_BINARY server
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

echo "5. Reloading systemd and starting service..."
systemctl daemon-reload
systemctl enable rke2-server.service
systemctl start rke2-server.service

echo "6. Checking service status..."
sleep 3
if systemctl is-active --quiet rke2-server.service; then
    echo "✅ RKE2 service is now running!"
    systemctl status rke2-server.service --no-pager -l
else
    echo "❌ Service still not running. Status:"
    systemctl status rke2-server.service --no-pager -l
    echo
    echo "Recent logs:"
    journalctl -u rke2-server.service --no-pager -n 10
fi

echo
echo "🏁 Quick fix complete!"
