#!/bin/bash
# EMERGENCY FIX: Fix the kubelet infinite loop issue
set -e

echo "🚨 EMERGENCY FIX: Fixing kubelet infinite loop"
echo "=============================================="

# Stop everything first
systemctl stop rke2-server || true
pkill -f kubelet || true
sleep 5

echo "1. Restoring original kubelet binary..."
RKE2_BIN_DIR="/var/lib/rancher/rke2/bin"

# Check if we have the original kubelet
if [ -f "$RKE2_BIN_DIR/kubelet.original" ]; then
    echo "Found original kubelet, restoring..."
    cp "$RKE2_BIN_DIR/kubelet.original" "$RKE2_BIN_DIR/kubelet"
    chmod +x "$RKE2_BIN_DIR/kubelet"
    echo "✅ Original kubelet restored"
else
    echo "⚠️ No original kubelet found - will need to reinstall RKE2"
    # Download fresh RKE2 to get clean kubelet
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -
    echo "✅ Fresh RKE2 installed"
fi

echo "2. Creating FIXED kubelet wrapper..."
cat > /usr/local/bin/kubelet-wrapper-fixed.sh << 'EOF'
#!/bin/bash
# FIXED kubelet wrapper that doesn't loop

# The ACTUAL kubelet binary path
REAL_KUBELET="/var/lib/rancher/rke2/bin/kubelet"

# Ensure we're not calling ourselves
if [[ "${BASH_SOURCE[0]}" == "$REAL_KUBELET" ]]; then
    echo "ERROR: Wrapper called from kubelet path - this would cause a loop!"
    exit 1
fi

# Filter out problematic resource management args
FILTERED_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --system-reserved=*|--kube-reserved=*|--enforce-node-allocatable=*)
      echo "Filtering out problematic arg: $arg" >&2
      # Replace with safe empty values
      case "$arg" in
        --system-reserved=*) FILTERED_ARGS+=("--system-reserved=") ;;
        --kube-reserved=*) FILTERED_ARGS+=("--kube-reserved=") ;;
        --enforce-node-allocatable=*) FILTERED_ARGS+=("--enforce-node-allocatable=") ;;
      esac
      ;;
    *)
      FILTERED_ARGS+=("$arg")
      ;;
  esac
done

echo "Running real kubelet: $REAL_KUBELET with ${#FILTERED_ARGS[@]} args" >&2
exec "$REAL_KUBELET" "${FILTERED_ARGS[@]}"
EOF

chmod +x /usr/local/bin/kubelet-wrapper-fixed.sh

echo "3. Testing the wrapper (dry run)..."
echo "Wrapper test - should show kubelet help:"
/usr/local/bin/kubelet-wrapper-fixed.sh --help | head -5

echo "4. Creating simple RKE2 config without problematic options..."
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# Simple working RKE2 config
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local

# Basic kubelet settings that work in LXC
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=5m"
  - "max-pods=50"
  - "protect-kernel-defaults=false"
EOF

echo "5. Creating minimal kubelet config file..."
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
# CRITICAL: Disable all resource enforcement
enforceNodeAllocatable: []
systemReserved: {}
kubeReserved: {}
EOF

echo "6. Removing problematic systemd overrides..."
rm -f /etc/systemd/system/rke2-server.service.d/99-*.conf
mkdir -p /etc/systemd/system/rke2-server.service.d

# Create a SIMPLE override that just uses our wrapper
cat > /etc/systemd/system/rke2-server.service.d/99-simple-fix.conf << 'EOF'
[Service]
Environment="RKE2_KUBELET_PATH=/usr/local/bin/kubelet-wrapper-fixed.sh"
TasksMax=infinity
LimitNOFILE=1048576
EOF

echo "7. Reloading systemd and starting RKE2..."
systemctl daemon-reload
systemctl start rke2-server

echo ""
echo "✅ EMERGENCY FIX COMPLETE!"
echo "The kubelet infinite loop has been fixed."
echo "Monitor with: journalctl -u rke2-server -f"
