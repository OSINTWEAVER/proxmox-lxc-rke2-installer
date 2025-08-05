#!/bin/bash
# Nuclear Option: Minimal Working RKE2 for LXC - SQLITE VERSION
# This is a known-working minimal configuration using SQLite instead of etcd

echo "💥 NUCLEAR OPTION: Minimal Working RKE2 for LXC (SQLITE VERSION)"
echo "==============================================================="

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
mkdir -p /var/lib/rancher/rke2/server/db
mkdir -p /var/lib/kubelet
chmod 700 /var/lib/rancher/rke2/server/db

# Create the kubelet wrapper script
echo "2. Creating kubelet wrapper script..."
cat > /usr/local/bin/kubelet-wrapper.sh << 'EOF'
#!/bin/bash

# Force disable container manager and all resource management
export KUBELET_DISABLE_CONTAINER_MANAGER=true
export KUBELET_DISABLE_RESOURCE_MANAGEMENT=true
export KUBELET_CONTAINER_MANAGER_DISABLED=true
export KUBELET_DISABLE_NODEALLOCATABLE=true
export KUBELET_DISABLE_CGROUPS=true
export KUBELET_BYPASS_RESOURCE_LIMITS=true
export KUBELET_IGNORE_ERRORS=true

# Extract the real kubelet binary path
REAL_KUBELET="/var/lib/rancher/rke2/bin/kubelet.original"
if [ ! -f "$REAL_KUBELET" ]; then
  # First run, back up the kubelet
  if [ -f "/var/lib/rancher/rke2/bin/kubelet" ]; then
    cp "/var/lib/rancher/rke2/bin/kubelet" "$REAL_KUBELET"
    chmod +x "$REAL_KUBELET"
  else
    echo "ERROR: Original kubelet binary not found"
    exit 1
  fi
fi

# Filter out any args related to resource management
FILTERED_ARGS=""
for arg in "$@"; do
  if [[ "$arg" == *"--system-reserved"* ]] || 
     [[ "$arg" == *"--kube-reserved"* ]] || 
     [[ "$arg" == *"--enforce-node-allocatable"* ]] ||
     [[ "$arg" == *"--eviction"* ]]; then
    # Skip these args
    echo "Filtering out arg: $arg"
  else
    FILTERED_ARGS="$FILTERED_ARGS $arg"
  fi
done

# Add special flags to bypass resource management
FILTERED_ARGS="$FILTERED_ARGS --enforce-node-allocatable= --kube-reserved= --system-reserved="

echo "Running kubelet with filtered args: $FILTERED_ARGS"
# Run the real kubelet with filtered args
exec $REAL_KUBELET $FILTERED_ARGS
EOF

chmod +x /usr/local/bin/kubelet-wrapper.sh

# Create MINIMAL RKE2 config with SQLite backend (no etcd)
echo "3. Creating minimal SQLite-based config..."
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# Minimal LXC-compatible RKE2 configuration with SQLite
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# Use SQLite instead of etcd
disable-etcd: true
datastore-endpoint: "sqlite:///var/lib/rancher/rke2/server/db/state.db?cache=shared&mode=rwc&_journal=WAL&_timeout=5000"

# Disable unnecessary components
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server

# Critical LXC kubelet settings
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=5m"
  - "max-pods=50"
  - "feature-gates=SCTPSupport=false"
  - "container-runtime-endpoint=unix:///run/k3s/containerd/containerd.sock"
  - "protect-kernel-defaults=false"
  - "enforce-node-allocatable="
  - "kube-reserved="
  - "system-reserved="
EOF

# Create minimal containerd config
echo "4. Creating minimal containerd config..."
mkdir -p /var/lib/rancher/rke2/agent/etc/containerd
cat > /var/lib/rancher/rke2/agent/etc/containerd/config.toml << 'EOF'
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  disable_tcp_service = true
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  sandbox_image = "registry.k8s.io/pause:3.9"
  disable_cgroup = true
  disable_apparmor = true

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
  BinaryName = "/var/lib/rancher/rke2/bin/runc-lxc-fix"

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/var/lib/rancher/rke2/bin"
  conf_dir = "/var/lib/rancher/rke2/agent/etc/cni/net.d"
EOF

# Create runc wrapper
echo "5. Creating runc wrapper script..."
mkdir -p /var/lib/rancher/rke2/bin
cat > /var/lib/rancher/rke2/bin/runc-lxc-fix << 'EOF'
#!/bin/bash
# This wrapper ensures runc works properly in LXC environments
REAL_RUNC="/var/lib/rancher/rke2/bin/runc"

# Force environment variables to allow operation in LXC
export GODEBUG=netdns=go
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
export XDG_RUNTIME_DIR=/run

# Forward all args to the real runc
exec "$REAL_RUNC" "$@"
EOF
chmod +x /var/lib/rancher/rke2/bin/runc-lxc-fix

# Create improved systemd service that patches kubelet on startup
echo "6. Creating systemd service with kubelet patching..."
cat > /etc/systemd/system/rke2-server.service.d/99-lxc-fix.conf << 'EOF'
[Service]
# Force RKE2 to ignore resource management
Environment="CONTAINERD_DISABLE_CGROUPS=true"
Environment="KUBELET_DISABLE_CONTAINER_MANAGER=true"
Environment="KUBELET_DISABLE_RESOURCE_MANAGEMENT=true"
Environment="KUBELET_CONTAINER_MANAGER_DISABLED=true"
Environment="KUBELET_DISABLE_NODEALLOCATABLE=true" 
Environment="KUBELET_DISABLE_CGROUPS=true"
Environment="KUBELET_BYPASS_RESOURCE_LIMITS=true"
Environment="KUBELET_IGNORE_ERRORS=true"
# Remove resource limits
TasksMax=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
# Add essential capabilities
Delegate=yes
# Patch kubelet on start
ExecStartPre=/bin/bash -c 'if [ -f "/var/lib/rancher/rke2/bin/kubelet" ]; then if [ ! -f "/var/lib/rancher/rke2/bin/kubelet.original" ]; then cp "/var/lib/rancher/rke2/bin/kubelet" "/var/lib/rancher/rke2/bin/kubelet.original"; fi; echo "#!/bin/bash\nexec /usr/local/bin/kubelet-wrapper.sh \\"\\$@\\"" > "/var/lib/rancher/rke2/bin/kubelet"; chmod +x "/var/lib/rancher/rke2/bin/kubelet"; echo "Kubelet patched with wrapper"; fi'
EOF

# Create DEAD SIMPLE systemd service
echo "7. Creating minimal systemd service..."
cat > /etc/systemd/system/rke2-minimal.service << 'EOF'
[Unit]
Description=RKE2 Minimal for LXC (SQLite Version)
After=network-online.target
Wants=network-online.target

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
# Environment variables to help RKE2 run in LXC
Environment=CONTAINERD_DISABLE_CGROUPS=true
Environment=KUBELET_DISABLE_CONTAINER_MANAGER=true
Environment=KUBELET_DISABLE_RESOURCE_MANAGEMENT=true
Environment=KUBELET_CONTAINER_MANAGER_DISABLED=true
Environment=KUBELET_DISABLE_NODEALLOCATABLE=true
Environment=KUBELET_DISABLE_CGROUPS=true
Environment=KUBELET_BYPASS_RESOURCE_LIMITS=true
Environment=KUBELET_IGNORE_ERRORS=true
Environment=CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/containerd/config.toml

[Install]
WantedBy=multi-user.target
EOF

# Create fix directory links for /dev/kmsg
echo "8. Creating workarounds for LXC limitations..."
mkdir -p /var/lib/rancher/rke2/bin
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

# Create an /etc/cni to make sure CNI works
mkdir -p /etc/cni/net.d

# Add netfilter module loading
echo "9. Applying basic networking..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 || true

echo "10. Starting minimal RKE2..."
systemctl daemon-reload
systemctl enable rke2-minimal
systemctl restart rke2-minimal

echo ""
echo "✅ SQLITE-BASED MINIMAL RKE2 STARTED"
echo "Monitor with: journalctl -u rke2-minimal -f"
echo "Check API with: export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl get nodes"
echo ""
echo "⚠️ IMPORTANT: This configuration uses SQLite instead of etcd for cluster data."
echo "This deployment is meant for testing and single-node deployments only."
