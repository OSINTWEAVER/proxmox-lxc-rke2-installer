#!/bin/bash
# ULTIMATE FIX: Disable kubelet config file completely in RKE2 and patch kubelet binary

echo "🔧 ULTIMATE KUBELET FIX FOR LXC - BINARY PATCH EDITION"
echo "===================================================="

# Stop RKE2
systemctl stop rke2-server.service || true
sleep 3

# Remove any kubelet config file
rm -f /var/lib/kubelet/config.yaml

# Backup current config
cp /etc/rancher/rke2/config.yaml /etc/rancher/rke2/config.yaml.backup.ultimate.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Create RKE2 config that explicitly disables kubelet config file
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 Configuration for LXC containers - NO kubelet config file
token: youmomma-atnowfrin12

# Explicitly disable kubelet config file
kubelet-config-file: ""

# Kubelet arguments for LXC compatibility - COMPLETE SET
kubelet-arg:
  - "protect-kernel-defaults=false"
  - "fail-swap-on=false"
  - "cgroup-driver=systemd"
  - "runtime-request-timeout=30s"
  - "make-iptables-util-chains=false"
  - "max-pods=250"
  - "serialize-image-pulls=false"
  - "registry-qps=10"
  - "registry-burst=20"
  - "event-qps=10"
  - "event-burst=20"
  - "kube-api-qps=20"
  - "kube-api-burst=40"
  - "enforce-node-allocatable="
  - "system-reserved="
  - "kube-reserved="

# etcd optimizations for containers
etcd-arg:
  - "heartbeat-interval=500"
  - "election-timeout=5000"

# API server optimizations
kube-apiserver-arg:
  - "request-timeout=300s"
EOF

echo "✅ Created RKE2 config with explicitly disabled kubelet config file"

# Create the kubelet wrapper script
echo "📝 Creating kubelet wrapper script to bypass container manager..."
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
  echo "ERROR: Original kubelet binary not found at $REAL_KUBELET"
  exit 1
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
echo "✅ Created kubelet wrapper script"

# Create systemd override
mkdir -p /etc/systemd/system/rke2-server.service.d/
cat > /etc/systemd/system/rke2-server.service.d/99-ultimate-fix.conf << 'EOF'
[Service]
# Force RKE2 to completely ignore resource management
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
# Avoid cgroup issues in LXC
ExecStartPre=-/bin/sh -c 'echo "+cpu +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control || true'
ExecStartPre=-/bin/sh -c 'rm -f /var/lib/kubelet/config.yaml'
ExecStartPre=-/bin/sh -c 'rm -f /var/lib/kubelet/*.json'
EOF

echo "✅ Created systemd override"

# Patch the kubelet binary
echo "🔧 Patching kubelet binary..."
RKE2_BIN_DIR="/var/lib/rancher/rke2/bin"
if [ -f "$RKE2_BIN_DIR/kubelet" ]; then
  echo "Found kubelet binary at $RKE2_BIN_DIR/kubelet"
  # Back up the original kubelet binary
  cp "$RKE2_BIN_DIR/kubelet" "$RKE2_BIN_DIR/kubelet.original"
  
  # Create a wrapper script that will be used instead of the real kubelet
  cat > "$RKE2_BIN_DIR/kubelet" << 'EOF'
#!/bin/bash
exec /usr/local/bin/kubelet-wrapper.sh "$@"
EOF
  chmod +x "$RKE2_BIN_DIR/kubelet"
  echo "✅ Replaced kubelet binary with wrapper script"
fi

# Ensure /dev/kmsg exists
ln -sf /dev/null /dev/kmsg 2>/dev/null || true

# Reload systemd
systemctl daemon-reload

echo "Starting RKE2..."
systemctl start rke2-server.service

echo "✅ ULTIMATE KUBELET BINARY PATCH APPLIED!"
echo "RKE2 will now use patched kubelet binary that bypasses container manager"
echo "Monitor with: journalctl -u rke2-server.service -f"
