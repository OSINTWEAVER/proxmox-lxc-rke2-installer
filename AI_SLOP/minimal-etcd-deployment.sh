#!/bin/bash
# MINIMAL RKE2 DEPLOYMENT - Back to basics with etcd
set -e

echo "🔧 MINIMAL RKE2 DEPLOYMENT - Back to Basics"
echo "==========================================="

# Stop everything and clean slate
echo "1. Stopping all services and cleaning up..."
systemctl stop rke2-server || true
systemctl stop containerd || true
pkill -f rke2 || true
pkill -f kubelet || true
pkill -f containerd || true
sleep 5

# Complete clean up
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /var/lib/kubelet
rm -rf /run/k3s
rm -rf /etc/systemd/system/rke2-server.service.d

echo "2. Fresh RKE2 installation..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "3. Creating ULTRA-MINIMAL config..."
mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml << 'EOF'
# Ultra-minimal RKE2 config
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# Absolutely minimal kubelet args - NOTHING that could cause parsing issues
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "protect-kernel-defaults=false"

# Keep etcd simple
etcd-arg:
  - "heartbeat-interval=1000"
  - "election-timeout=10000"
EOF

echo "4. Creating the most basic kubelet config possible..."
cat > /etc/rancher/rke2/kubelet-config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# Container runtime
containerRuntimeEndpoint: "unix:///run/k3s/containerd/containerd.sock"
runtimeRequestTimeout: "15m0s"

# Basic authentication
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true

authorization:
  mode: Webhook

# DNS
clusterDNS:
  - "10.43.0.10"
clusterDomain: "cluster.local"

# Cgroup
cgroupDriver: "systemd"
failSwapOn: false
protectKernelDefaults: false

# ABSOLUTELY NO RESOURCE MANAGEMENT - Leave all empty/default
# Don't even mention these fields to avoid parsing issues
EOF

echo "5. Creating simple kubelet binary wrapper..."
cat > /usr/local/bin/simple-kubelet-wrapper.sh << 'EOF'
#!/bin/bash
# Simple kubelet wrapper - just remove the problematic args

# Find the real kubelet
REAL_KUBELET="/var/lib/rancher/rke2/bin/kubelet"

# Simple argument filtering - remove only the problematic ones
CLEAN_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --system-reserved=*|--kube-reserved=*|--enforce-node-allocatable=*)
            # Skip these completely - don't even add empty versions
            echo "Skipping problematic arg: $arg" >&2
            ;;
        *)
            CLEAN_ARGS+=("$arg")
            ;;
    esac
done

echo "Starting kubelet with ${#CLEAN_ARGS[@]} clean args" >&2
exec "$REAL_KUBELET" "${CLEAN_ARGS[@]}"
EOF

chmod +x /usr/local/bin/simple-kubelet-wrapper.sh

echo "6. Test the wrapper..."
echo "Testing wrapper (should show kubelet version):"
/usr/local/bin/simple-kubelet-wrapper.sh --version

echo "7. Patch kubelet binary ONLY if it works..."
RKE2_BIN_DIR="/var/lib/rancher/rke2/bin"
if [ -f "$RKE2_BIN_DIR/kubelet" ]; then
    # Backup original
    cp "$RKE2_BIN_DIR/kubelet" "$RKE2_BIN_DIR/kubelet.real"
    
    # Create simple redirect script
    cat > "$RKE2_BIN_DIR/kubelet" << 'EOF'
#!/bin/bash
exec /usr/local/bin/simple-kubelet-wrapper.sh "$@"
EOF
    chmod +x "$RKE2_BIN_DIR/kubelet"
    echo "✅ Kubelet patched with simple wrapper"
fi

echo "8. Basic networking setup..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true

# Fix /dev/kmsg for LXC
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "9. Starting RKE2 with default systemd service..."
systemctl daemon-reload
systemctl enable rke2-server
systemctl start rke2-server

echo ""
echo "✅ MINIMAL DEPLOYMENT COMPLETE!"
echo "=============================="
echo "This is the most basic possible RKE2 setup with etcd."
echo "The kubelet wrapper only removes the problematic arguments."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
echo "Check status: systemctl status rke2-server"
echo ""
echo "If this works, we can add complexity back gradually."
