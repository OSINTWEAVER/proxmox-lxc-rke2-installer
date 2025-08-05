#!/bin/bash
# TOTAL ANNIHILATION - Maximum force cleanup
set +e  # Don't exit on errors

echo "☢️ TOTAL ANNIHILATION - MAXIMUM FORCE CLEANUP"
echo "=============================================="

echo "1. Maximum force process termination..."
killall -9 rke2 2>/dev/null || true
killall -9 kubelet 2>/dev/null || true
killall -9 containerd 2>/dev/null || true
killall -9 etcd 2>/dev/null || true

systemctl stop rke2-server 2>/dev/null || true
systemctl stop rke2-agent 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true

sleep 5

echo "2. Force unmounting everything..."
# Unmount all RKE2-related mounts with maximum force
for mount in $(mount | grep -E "(rke2|k3s|kubelet|rancher)" | awk '{print $3}' | sort -r); do
    echo "Force unmounting: $mount"
    umount -l "$mount" 2>/dev/null || true
    umount -f "$mount" 2>/dev/null || true
done

# Specific LXC-related unmounts
umount -l /var/lib/rancher/rke2/agent/proc-sys-stubs/* 2>/dev/null || true
umount -f /var/lib/rancher/rke2/agent/proc-sys-stubs/* 2>/dev/null || true

echo "3. Maximum force directory removal..."
# Use rm with maximum force and ignore all errors
rm -rf /var/lib/rancher 2>/dev/null || true
rm -rf /etc/rancher 2>/dev/null || true
rm -rf /var/lib/kubelet 2>/dev/null || true
rm -rf /run/k3s 2>/dev/null || true
rm -rf /run/flannel 2>/dev/null || true
rm -rf /var/log/rke2 2>/dev/null || true

# Remove systemd files
rm -rf /etc/systemd/system/rke2* 2>/dev/null || true
rm -rf /usr/local/lib/systemd/system/rke2* 2>/dev/null || true

# Remove binaries
rm -f /usr/local/bin/rke2 2>/dev/null || true
rm -f /usr/local/bin/*kubelet* 2>/dev/null || true

echo "4. Disable and mask services..."
systemctl disable rke2-server 2>/dev/null || true
systemctl disable rke2-agent 2>/dev/null || true
systemctl mask rke2-server 2>/dev/null || true
systemctl mask rke2-agent 2>/dev/null || true

echo "5. Final cleanup attempt with different methods..."
# Try different removal methods
find /var/lib -name "*rke2*" -exec rm -rf {} + 2>/dev/null || true
find /etc -name "*rke2*" -exec rm -rf {} + 2>/dev/null || true
find /usr/local -name "*rke2*" -exec rm -rf {} + 2>/dev/null || true

echo "6. Reset systemd..."
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo "7. Force recreate directories if they still exist..."
if [ -d "/var/lib/rancher" ]; then
    echo "Directory still exists, trying to recreate..."
    cd /tmp
    rm -rf /var/lib/rancher 2>/dev/null || true
fi

echo ""
echo "☢️ TOTAL ANNIHILATION COMPLETE!"
echo "=============================="
echo "Used maximum force to remove everything."
echo "If directories still exist, a reboot may be required."
echo ""
echo "Check if clean:"
echo "ls -la /var/lib/rancher 2>/dev/null || echo 'Clean!'"
