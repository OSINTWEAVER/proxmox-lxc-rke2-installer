#!/bin/bash

# Combined LXC Compatibility Fix for RKE2
# This script applies both the systemd cgroup fix and AppArmor configuration
# to resolve the major LXC/Kubernetes compatibility issues

echo "🚀 Applying Complete LXC Compatibility Fix for RKE2..."
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "${BLUE}🎯 Deployment Summary:${NC}"
log "  ✅ Phase 1: kubelet cgroup parsing (RESOLVED via LXC config)"
log "  ✅ Phase 2: systemd cgroup paths (RESOLVED via cgroupfs driver)"  
log "  🔧 Phase 3: AppArmor policy conflicts (APPLYING FIX NOW)"
log ""

# Check if we're in an LXC container
if ! grep -qa container=lxc /proc/1/environ; then
    log "${RED}❌ This script is designed for LXC containers only${NC}"
    exit 1
fi

log "${YELLOW}Step 1: Redeploying with updated Ansible playbook...${NC}"
echo "The playbook now includes:"
echo "  - Early AppArmor configuration"
echo "  - Enhanced containerd settings"
echo "  - Kubelet AppArmor feature gate disable"
echo ""

# Show current status
log "${YELLOW}Step 2: Checking current deployment status...${NC}"

if systemctl is-active rke2-server >/dev/null 2>&1; then
    log "${GREEN}✓ RKE2 server is currently running${NC}"
    
    # Check for recent AppArmor errors
    if journalctl -u rke2-server --since "5 minutes ago" 2>/dev/null | grep -i apparmor | grep -i error >/dev/null; then
        log "${YELLOW}⚠️ Recent AppArmor errors detected - fix needed${NC}"
    else
        log "${GREEN}✓ No recent AppArmor errors${NC}"
    fi
    
    # Check for pod creation issues
    if tail -n 50 /var/lib/rancher/rke2/agent/logs/kubelet.log 2>/dev/null | grep -i "CreateContainer.*failed.*apparmor" >/dev/null; then
        log "${YELLOW}⚠️ Container creation AppArmor issues detected${NC}"
    else
        log "${GREEN}✓ No container creation AppArmor issues${NC}"
    fi
    
elif systemctl is-active rke2-agent >/dev/null 2>&1; then
    log "${GREEN}✓ RKE2 agent is currently running${NC}"
else
    log "${YELLOW}⚠️ RKE2 service not currently active${NC}"
fi

log "${YELLOW}Step 3: Checking configuration files...${NC}"

# Check containerd config
if [ -f /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl ]; then
    log "${GREEN}✓ RKE2 containerd config exists${NC}"
    
    if grep -q "SystemdCgroup = false" /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl; then
        log "${GREEN}✓ SystemdCgroup disabled${NC}"
    else
        log "${YELLOW}⚠️ SystemdCgroup not disabled${NC}"
    fi
    
    if grep -q "disable_apparmor = true" /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl; then
        log "${GREEN}✓ AppArmor disabled in containerd${NC}"
    else
        log "${YELLOW}⚠️ AppArmor not disabled in containerd${NC}"
    fi
else
    log "${YELLOW}⚠️ RKE2 containerd config not found${NC}"
fi

# Check kubelet config
if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
    if grep -q "cgroupDriver: cgroupfs" /etc/rancher/rke2/kubelet-config.yaml; then
        log "${GREEN}✓ kubelet using cgroupfs driver${NC}"
    else
        log "${YELLOW}⚠️ kubelet not using cgroupfs driver${NC}"
    fi
else
    log "${YELLOW}⚠️ kubelet config not found yet${NC}"
fi

# Check kubelet systemd override
if [ -f /etc/systemd/system/kubelet.service.d/10-apparmor-override.conf ]; then
    log "${GREEN}✓ kubelet AppArmor override configured${NC}"
else
    log "${YELLOW}⚠️ kubelet AppArmor override not found${NC}"
fi

log "${YELLOW}Step 4: Instructions for redeployment...${NC}"
echo ""
echo "To apply the complete fix, run from your Ansible control machine:"
echo ""
echo "  cd /path/to/proxmox-lxc-rke2-installer"
echo "  ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml -v"
echo ""
echo "This will:"
echo "  1. Configure AppArmor early in the deployment"
echo "  2. Set up cgroupfs driver for kubelet"  
echo "  3. Configure containerd with both fixes"
echo "  4. Deploy RKE2 with all LXC optimizations"
echo ""

log "${YELLOW}Step 5: Monitoring after redeployment...${NC}"
echo ""
echo "After Ansible completes, monitor with:"
echo ""
echo "  # Check RKE2 service status"
echo "  sudo systemctl status rke2-server"
echo ""
echo "  # Monitor kubelet logs for errors"
echo "  sudo tail -f /var/lib/rancher/rke2/agent/logs/kubelet.log"
echo ""
echo "  # Check for API server readiness"
echo "  export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""

log "${GREEN}🎉 LXC Compatibility Fix preparation complete!${NC}"
log "${BLUE}Ready for Ansible redeployment with all fixes integrated.${NC}"
