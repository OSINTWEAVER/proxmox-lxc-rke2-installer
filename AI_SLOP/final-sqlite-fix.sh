#!/bin/bash
# FINAL FIX: Complete SQLite-only RKE2 deployment that bypasses etcd entirely
set -e

echo "🔥 FINAL FIX: Complete SQLite-only RKE2 deployment"
echo "================================================="

# Stop everything and clean up
systemctl stop rke2-server || true
pkill -f rke2 || true
pkill -f kubelet || true
pkill -f containerd || true
sleep 5

echo "1. Complete cleanup of previous installation..."
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /var/lib/kubelet
rm -rf /run/k3s

echo "2. Fresh RKE2 installation..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "3. Creating SQLite-only configuration..."
mkdir -p /etc/rancher/rke2
mkdir -p /var/lib/rancher/rke2/server/db
chmod 700 /var/lib/rancher/rke2/server/db

cat > /etc/rancher/rke2/config.yaml << 'EOF'
# SQLite-only RKE2 configuration
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# FORCE SQLite datastore - no etcd
disable-etcd: true
datastore-endpoint: "sqlite:///var/lib/rancher/rke2/server/db/state.db?cache=shared&mode=rwc&_journal=WAL&_timeout=5000"

# Disable unnecessary components to reduce complexity
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server

# Critical kubelet settings for LXC
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=5m"
  - "max-pods=50"
  - "protect-kernel-defaults=false"
  - "enforce-node-allocatable="
  - "kube-reserved="
  - "system-reserved="
EOF

echo "4. Creating minimal kubelet config..."
cat > /etc/rancher/rke2/kubelet-config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
containerRuntimeEndpoint: "unix:///run/k3s/containerd/containerd.sock"
runtimeRequestTimeout: "15m0s"
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook
clusterDNS:
  - "10.43.0.10"
clusterDomain: "cluster.local"
cgroupDriver: "systemd"
failSwapOn: false
protectKernelDefaults: false
# DISABLE ALL RESOURCE MANAGEMENT
enforceNodeAllocatable: []
systemReserved: {}
kubeReserved: {}
evictionHard: {}
evictionSoft: {}
EOF

echo "5. Creating working kubelet wrapper..."
cat > /usr/local/bin/kubelet-safe.sh << 'EOF'
#!/bin/bash
# Safe kubelet wrapper that prevents resource management issues

REAL_KUBELET="/usr/local/bin/rke2-kubelet-original"

# Back up original kubelet if not done
if [ ! -f "$REAL_KUBELET" ] && [ -f "/var/lib/rancher/rke2/bin/kubelet" ]; then
    cp "/var/lib/rancher/rke2/bin/kubelet" "$REAL_KUBELET"
    chmod +x "$REAL_KUBELET"
fi

# Use the backed up kubelet or the one from PATH
if [ -f "$REAL_KUBELET" ]; then
    KUBELET_BIN="$REAL_KUBELET"
else
    KUBELET_BIN="/var/lib/rancher/rke2/bin/kubelet"
fi

# Filter out problematic arguments
SAFE_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --system-reserved=*|--kube-reserved=*|--enforce-node-allocatable=*)
            # Replace with safe empty values
            case "$arg" in
                --system-reserved=*) SAFE_ARGS+=("--system-reserved=") ;;
                --kube-reserved=*) SAFE_ARGS+=("--kube-reserved=") ;;
                --enforce-node-allocatable=*) SAFE_ARGS+=("--enforce-node-allocatable=") ;;
            esac
            ;;
        *)
            SAFE_ARGS+=("$arg")
            ;;
    esac
done

echo "Starting kubelet with ${#SAFE_ARGS[@]} args" >&2
exec "$KUBELET_BIN" "${SAFE_ARGS[@]}"
EOF

chmod +x /usr/local/bin/kubelet-safe.sh

echo "6. Creating systemd override for SQLite mode..."
mkdir -p /etc/systemd/system/rke2-server.service.d
cat > /etc/systemd/system/rke2-server.service.d/99-sqlite-mode.conf << 'EOF'
[Service]
# Environment variables for SQLite mode
Environment="RKE2_DATA_DIR=/var/lib/rancher/rke2"
Environment="RKE2_CONFIG_FILE=/etc/rancher/rke2/config.yaml"
# Remove resource limits
TasksMax=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
# Essential capabilities
Delegate=yes
# Patch kubelet before starting
ExecStartPre=/bin/bash -c 'if [ -f "/var/lib/rancher/rke2/bin/kubelet" ] && [ ! -f "/usr/local/bin/rke2-kubelet-original" ]; then cp "/var/lib/rancher/rke2/bin/kubelet" "/usr/local/bin/rke2-kubelet-original"; echo "#!/bin/bash\nexec /usr/local/bin/kubelet-safe.sh \\"\\$@\\"" > "/var/lib/rancher/rke2/bin/kubelet"; chmod +x "/var/lib/rancher/rke2/bin/kubelet"; echo "Kubelet patched"; fi'
EOF

echo "7. Set up networking for LXC..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 || true

# Create /dev/kmsg workaround
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "8. Starting SQLite-based RKE2..."
systemctl daemon-reload
systemctl enable rke2-server
systemctl start rke2-server

echo ""
echo "✅ SQLITE-BASED RKE2 DEPLOYMENT COMPLETE!"
echo "========================================="
echo "This deployment uses SQLite instead of etcd and should avoid the kubelet issues."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
echo "Check status: systemctl status rke2-server"
echo ""
echo "Once running, test with:"
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
echo "/var/lib/rancher/rke2/bin/kubectl get nodes"
