#!/bin/bash
# LXC-specific RKE2 debugging and fixes
# Run this on your control-plane container (10.14.100.1)

echo "🔧 LXC RKE2 Deep Troubleshooting & Fixes"
echo "========================================"

echo "1. Stopping RKE2 to apply fixes..."
systemctl stop rke2-server.service || true
sleep 5

echo "2. Checking LXC container configuration..."
echo "Container type detection:"
if grep -qa container=lxc /proc/1/environ; then
    echo "✅ Confirmed: Running in LXC container"
else
    echo "⚠️ Not detected as LXC - may be different container type"
fi

echo
echo "Available capabilities:"
cat /proc/self/status | grep Cap || echo "Capabilities not available"

echo
echo "3. Checking cgroup configuration..."
if [ -d /sys/fs/cgroup/systemd ]; then
    echo "✅ systemd cgroup available"
else
    echo "❌ systemd cgroup missing - this will cause issues"
fi

if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "Available cgroup controllers:"
    cat /sys/fs/cgroup/cgroup.controllers
else
    echo "Legacy cgroup v1 detected"
fi

echo
echo "4. Checking filesystem permissions..."
echo "RKE2 data directory permissions:"
ls -la /var/lib/rancher/rke2/ || echo "Directory doesn't exist yet"

echo
echo "5. Creating LXC-compatible RKE2 configuration..."

# Create enhanced RKE2 config for LXC
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# LXC-compatible RKE2 configuration
token: youmomma-atnowfrin12
data-dir: /var/lib/rancher/rke2
cni: [flannel]
tls-san:
  - cluster.local
  - 10.14.100.1
node-name: os-env-control-plane-1
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16

# LXC-specific kubelet arguments
kubelet-arg:
  - "feature-gates=SCTPSupport=false"
  - "allowed-unsafe-sysctls=net.core.somaxconn"
  - "runtime-request-timeout=15m"
  - "cgroup-driver=systemd"
  - "fail-swap-on=false"

# LXC-compatible etcd settings  
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"
  - "quota-backend-bytes=8589934592"

# Disable problematic features in LXC
disable-cloud-controller: true
EOF

echo "6. Checking and fixing container runtime..."
echo "Containerd status:"
systemctl status containerd --no-pager -l || echo "Containerd not running"

echo
echo "7. Fixing systemd service for LXC..."
cat > /usr/local/lib/systemd/system/rke2-server.service << 'EOF'
[Unit]
Description=Rancher Kubernetes Engine v2 (server) - LXC Optimized
Documentation=https://github.com/rancher/rke2#readme
Wants=network-online.target
After=network-online.target
ConflictsWith=rke2-agent.service

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
# Skip all kernel module checks for LXC
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service'
ExecStart=/usr/local/bin/rke2 server
ExecStopPost=/bin/sh -c "systemctl kill --kill-who=all --signal=SIGTERM rke2-server.service || true"
KillMode=mixed
Delegate=yes
# Generous timeouts for LXC
TimeoutStartSec=600
TimeoutStopSec=300
RestartSec=10
Restart=on-failure
RestartPreventExitStatus=78
# LXC resource limits
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
# Enhanced logging
StandardOutput=journal
StandardError=journal
# Environment
EnvironmentFile=-/etc/default/rke2-server
# LXC-specific environment
Environment="RKE2_TOKEN=youmomma-atnowfrin12"
Environment="CONTAINERD_LOG_LEVEL=debug"
EOF

echo "8. Setting up sysctl for LXC networking..."
cat > /etc/sysctl.d/99-rke2-lxc.conf << 'EOF'
# LXC-compatible networking for RKE2
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
# LXC networking optimization
net.core.somaxconn = 32768
net.netfilter.nf_conntrack_max = 1000000
vm.max_map_count = 262144
EOF

sysctl --system 2>/dev/null || true

echo "9. Reloading systemd and attempting restart..."
systemctl daemon-reload
systemctl enable rke2-server.service

echo "10. Starting RKE2 with verbose logging..."
systemctl start rke2-server.service

echo "11. Monitoring startup (will wait up to 5 minutes)..."
for i in {1..30}; do
    echo "Attempt $i/30 ($(($i * 10)) seconds)..."
    
    if systemctl is-active --quiet rke2-server.service; then
        echo "✅ RKE2 service is now active!"
        break
    fi
    
    if [ $i -eq 15 ]; then
        echo "Halfway point - checking logs..."
        journalctl -u rke2-server.service --no-pager -n 5
    fi
    
    sleep 10
done

echo
echo "12. Final status check..."
systemctl status rke2-server.service --no-pager -l

echo
echo "Recent logs:"
journalctl -u rke2-server.service --no-pager -n 10

echo
echo "🏁 LXC fixes applied!"
echo
if systemctl is-active --quiet rke2-server.service; then
    echo "✅ SUCCESS: RKE2 is running!"
    echo "Try testing the API in a few minutes with:"
    echo "  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
    echo "  /var/lib/rancher/rke2/bin/kubectl get nodes"
else
    echo "❌ Still having issues. Check the logs above for specific errors."
fi
