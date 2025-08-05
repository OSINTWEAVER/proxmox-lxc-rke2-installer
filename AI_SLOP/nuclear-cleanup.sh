#!/bin/bash
# NUCLEAR OPTION: Complete destruction and fresh start
set -e

echo "💥 NUCLEAR CLEANUP - DESTROYING EVERYTHING"
echo "=========================================="

echo "1. Killing all processes..."
systemctl stop rke2-server || true
systemctl stop rke2-agent || true
systemctl stop containerd || true
systemctl stop docker || true
pkill -f rke2 || true
pkill -f kubelet || true
pkill -f containerd || true
pkill -f etcd || true
sleep 10

echo "2. Disabling services..."
systemctl disable rke2-server || true
systemctl disable rke2-agent || true

echo "3. Nuclear filesystem cleanup..."
# Force unmount anything mounted
umount -f /var/lib/rancher/rke2/agent/proc-sys-stubs/* 2>/dev/null || true
umount -f /var/lib/rancher/rke2/agent/containerd/tmpmounts/* 2>/dev/null || true

# Remove everything RKE2 related
rm -rf /var/lib/rancher/rke2 2>/dev/null || true
rm -rf /etc/rancher/rke2 2>/dev/null || true
rm -rf /var/lib/kubelet 2>/dev/null || true
rm -rf /run/k3s 2>/dev/null || true
rm -rf /run/flannel 2>/dev/null || true

# Remove systemd overrides
rm -rf /etc/systemd/system/rke2-server.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/rke2-agent.service.d 2>/dev/null || true

# Remove wrapper scripts
rm -f /usr/local/bin/*kubelet* 2>/dev/null || true
rm -f /usr/local/bin/*rke2* 2>/dev/null || true

# Remove logs
rm -rf /var/log/rke2 2>/dev/null || true

echo "4. Removing RKE2 binaries..."
rm -f /usr/local/bin/rke2 2>/dev/null || true
rm -rf /usr/local/lib/systemd/system/rke2* 2>/dev/null || true

echo "5. Cleaning up any remaining mounts..."
# Force cleanup of any remaining mounts
for mount in $(mount | grep -E "(rke2|k3s|kubelet)" | awk '{print $3}' | sort -r); do
    umount -f "$mount" 2>/dev/null || true
done

echo "6. Reloading systemd..."
systemctl daemon-reload

echo "7. Starting Docker (we'll keep this)..."
systemctl start docker
systemctl enable docker

echo ""
echo "💥 NUCLEAR CLEANUP COMPLETE!"
echo "============================"
echo "Everything RKE2-related has been destroyed."
echo "The system is now clean and ready for a fresh installation."
echo ""
echo "Next steps:"
echo "1. Reboot the container for a completely clean state (optional but recommended)"
echo "2. Run a fresh RKE2 installation script"
