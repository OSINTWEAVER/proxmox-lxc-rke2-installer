#!/bin/bash
# SUPER CLEAN RKE2 DEPLOYMENT - Remove all previous overrides
set -e

echo "🧹 SUPER CLEAN RKE2 DEPLOYMENT"
echo "=============================="

# Stop everything
echo "1. Stopping all services..."
systemctl stop rke2-server || true
pkill -f rke2 || true
pkill -f kubelet || true
sleep 5

echo "2. Complete cleanup including systemd overrides..."
rm -rf /var/lib/rancher/rke2
rm -rf /etc/rancher/rke2
rm -rf /var/lib/kubelet
rm -rf /run/k3s
rm -rf /etc/systemd/system/rke2-server.service.d
rm -f /usr/local/bin/*kubelet*wrapper*
rm -f /usr/local/bin/simple-kubelet-wrapper.sh

echo "3. Fresh RKE2 installation..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.6+rke2r1 sh -

echo "4. Creating minimal config..."
mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml << 'EOF'
token: mytoken12345
node-name: control-plane
tls-san:
  - 10.14.100.1
  - cluster.local
kubelet-arg:
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "protect-kernel-defaults=false"
EOF

echo "5. Creating minimal kubelet config..."
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
enforceNodeAllocatable: []
systemReserved: {}
kubeReserved: {}
EOF

echo "6. Creating clean kubelet wrapper..."
cat > /usr/local/bin/clean-kubelet-wrapper.sh << 'EOF'
#!/bin/bash
REAL_KUBELET="/var/lib/rancher/rke2/bin/kubelet"

# Filter arguments
CLEAN_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --system-reserved=*|--kube-reserved=*|--enforce-node-allocatable=*)
            # Skip these args completely
            ;;
        *)
            CLEAN_ARGS+=("$arg")
            ;;
    esac
done

exec "$REAL_KUBELET" "${CLEAN_ARGS[@]}"
EOF

chmod +x /usr/local/bin/clean-kubelet-wrapper.sh

echo "7. Patch kubelet after RKE2 starts..."
# We'll patch kubelet AFTER rke2 installs it
cat > /usr/local/bin/patch-kubelet.sh << 'EOF'
#!/bin/bash
RKE2_BIN_DIR="/var/lib/rancher/rke2/bin"
if [ -f "$RKE2_BIN_DIR/kubelet" ] && [ ! -f "$RKE2_BIN_DIR/kubelet.original" ]; then
    cp "$RKE2_BIN_DIR/kubelet" "$RKE2_BIN_DIR/kubelet.original"
    cat > "$RKE2_BIN_DIR/kubelet" << 'WRAPPER'
#!/bin/bash
exec /usr/local/bin/clean-kubelet-wrapper.sh "$@"
WRAPPER
    chmod +x "$RKE2_BIN_DIR/kubelet"
    echo "Kubelet patched successfully"
fi
EOF

chmod +x /usr/local/bin/patch-kubelet.sh

echo "8. Creating ONE SIMPLE systemd override..."
mkdir -p /etc/systemd/system/rke2-server.service.d
cat > /etc/systemd/system/rke2-server.service.d/clean-override.conf << 'EOF'
[Service]
# Patch kubelet before starting
ExecStartPre=/usr/local/bin/patch-kubelet.sh
# Remove resource limits for LXC
TasksMax=infinity
LimitNOFILE=1048576
EOF

echo "9. Basic LXC setup..."
modprobe br_netfilter || true
modprobe overlay || true
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

echo "10. Starting clean RKE2..."
systemctl daemon-reload
systemctl enable rke2-server
systemctl start rke2-server

echo ""
echo "✅ SUPER CLEAN DEPLOYMENT COMPLETE!"
echo "=================================="
echo "All previous overrides removed. Fresh start with minimal config."
echo ""
echo "Monitor with: journalctl -u rke2-server -f"
echo ""
echo "The kubelet will be patched after RKE2 starts."
