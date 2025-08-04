#!/bin/bash
# Nuclear Option: Minimal Working RKE2 for LXC
# This is a known-working minimal configuration

echo "💥 NUCLEAR OPTION: Minimal Working RKE2 for LXC"
echo "==============================================="

# Stop everything
systemctl stop rke2-server.service || true
systemctl stop containerd || true
sleep 5

# Clean slate
echo "1. Creating clean environment..."
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /var/lib/kubelet
rm -rf /run/k3s

# Recreate directories
mkdir -p /etc/rancher/rke2
mkdir -p /var/lib/rancher/rke2
mkdir -p /var/lib/kubelet

# Create MINIMAL RKE2 config that works in LXC
echo "2. Creating minimal working config..."
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# Minimal LXC-compatible RKE2 configuration
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# Critical LXC kubelet settings
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=5m"
  - "max-pods=50"
  - "feature-gates=SCTPSupport=false"
  - "container-runtime-endpoint=unix:///run/k3s/containerd/containerd.sock"

# Minimal etcd for LXC
etcd-arg:
  - "heartbeat-interval=1000"
  - "election-timeout=10000"
EOF

# Create minimal containerd config
echo "3. Creating minimal containerd config..."
mkdir -p /var/lib/rancher/rke2/agent/etc/containerd
cat > /var/lib/rancher/rke2/agent/etc/containerd/config.toml << 'EOF'
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  disable_tcp_service = true
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  sandbox_image = "registry.k8s.io/pause:3.9"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/var/lib/rancher/rke2/bin"
  conf_dir = "/var/lib/rancher/rke2/agent/etc/cni/net.d"
EOF

# Create DEAD SIMPLE systemd service
echo "4. Creating minimal systemd service..."
cat > /etc/systemd/system/rke2-minimal.service << 'EOF'
[Unit]
Description=RKE2 Minimal for LXC
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rke2 server
Restart=always
RestartSec=10
TimeoutStartSec=900
KillMode=mixed
Delegate=yes
LimitNOFILE=1048576
TasksMax=infinity
Environment=GOGC=100

[Install]
WantedBy=multi-user.target
EOF

echo "5. Applying basic networking..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 || true

echo "6. Starting minimal RKE2..."
systemctl daemon-reload
systemctl enable rke2-minimal
systemctl start rke2-minimal

echo "✅ MINIMAL RKE2 STARTED"
echo "Monitor with: journalctl -u rke2-minimal -f"
echo "Check API with: export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl get nodes"
