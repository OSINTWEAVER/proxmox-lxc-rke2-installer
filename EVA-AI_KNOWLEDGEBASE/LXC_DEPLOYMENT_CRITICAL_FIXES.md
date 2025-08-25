# Critical LXC Deployment Fixes

## 🚨 CRITICAL ISSUES IDENTIFIED

Based on the deployment failure analysis, these critical issues must be fixed:

### 1. **UNPRIVILEGED CONTAINER ERROR**
**Status**: ❌ CRITICAL - Deployment will fail
**Issue**: "ERROR: Container appears to be unprivileged (limited capabilities)"
**Impact**: Kubernetes components cannot access required kernel features

**REQUIRED FIX**:
```bash
# Containers must be created as privileged with nesting features
# Use these parameters during container creation:

pct create {ID} {template} \
  --unprivileged 0 \
  --features fuse=1,keyctl=1,nesting=1

# DO NOT add conflicting lxc.apparmor.profile settings
# The nesting=1 feature handles security profiles automatically
```

### 2. **BR_NETFILTER MODULE NOT LOADED**
**Status**: ❌ CRITICAL - Networking will fail
**Issue**: "ERROR: br_netfilter: NOT LOADED"
**Impact**: Kubernetes networking (pods, services) will not function

**REQUIRED FIX**:
```bash
# On Proxmox host (not in container)
modprobe br_netfilter
echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf

# Verify it's loaded
lsmod | grep br_netfilter
```

### 3. **SYSCTL PERMISSION ERRORS**
**Status**: ❌ CRITICAL - Container configuration insufficient
**Issue**: Multiple "permission denied" errors on kernel parameters
**Impact**: Kubernetes will fail to configure required kernel settings

**REQUIRED FIX**:
```bash
# On Proxmox host, edit LXC container configuration
nano /etc/pve/lxc/{CONTAINER_ID}.conf

# Add syscall allowances:
lxc.seccomp.profile: 
lxc.mount.auto: cgroup:rw
```

### 4. **DEVICE ACCESS FOR KUBERNETES**
**Status**: ❌ REQUIRED - Container needs device access
**Issue**: Kubernetes requires access to various devices
**Impact**: kubelet and container runtime will fail

**REQUIRED FIX**:
```bash
# On Proxmox host, edit LXC container configuration  
nano /etc/pve/lxc/{CONTAINER_ID}.conf

# Add device access:
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,optional,create=file
```

## 🔧 COMPLETE LXC CONTAINER CONFIGURATION

### Recommended LXC Configuration File:
```ini
# /etc/pve/lxc/{CONTAINER_ID}.conf

# Basic container settings
arch: amd64
cores: 4
memory: 8192
net0: name=eth0,bridge=vmbr0,ip=dhcp,type=veth
ostype: ubuntu
rootfs: local-lvm:vm-{ID}-disk-0,size=50G
swap: 0

# CRITICAL: Privileged mode for Kubernetes
privileged: 1

# CRITICAL: Container features for Kubernetes (set during creation)
# These are set with --features fuse=1,keyctl=1,nesting=1 during pct create
# DO NOT manually add lxc.apparmor.profile settings when using nesting=1

# CRITICAL: Device access
lxc.cgroup.devices.allow: a
lxc.cap.drop:

# CRITICAL: Mount options for Kubernetes
lxc.mount.auto: cgroup:rw proc:rw sys:rw
lxc.mount.entry: /dev/kmsg dev/kmsg none bind,optional,create=file
lxc.mount.entry: /lib/modules lib/modules none bind,ro,optional

# CRITICAL: Syscall access (remove seccomp restrictions)
lxc.seccomp.profile:

# GPU passthrough (if needed)
# lxc.cgroup2.devices.allow: c 195:* rwm
# lxc.cgroup2.devices.allow: c 509:* rwm
# lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
# lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
# lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
```

**IMPORTANT**: Do NOT add `lxc.apparmor.profile: unconfined` when using `features: nesting=1`. These settings conflict with each other. The `nesting=1` feature handles the necessary security profile automatically.

## 🚀 DEPLOYMENT WORKFLOW

### Step 1: Fix Container Configuration
```bash
# Stop container
pct stop {CONTAINER_ID}

# Edit configuration  
nano /etc/pve/lxc/{CONTAINER_ID}.conf
# Add all the settings above

# Start container
pct start {CONTAINER_ID}
```

### Step 2: Load Required Kernel Modules on Proxmox Host
```bash
# Load bridge netfilter
modprobe br_netfilter
modprobe overlay
modprobe ip_tables
modprobe ip6_tables

# Make persistent
echo 'br_netfilter' >> /etc/modules-load.d/kubernetes.conf
echo 'overlay' >> /etc/modules-load.d/kubernetes.conf
echo 'ip_tables' >> /etc/modules-load.d/kubernetes.conf
echo 'ip6_tables' >> /etc/modules-load.d/kubernetes.conf

# Configure sysctl on Proxmox host
cat <<EOF > /etc/sysctl.d/k8s-bridge.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

### Step 3: Verify Container Capabilities
```bash
# Enter container
pct enter {CONTAINER_ID}

# Check privileged status
cat /proc/1/status | grep CapEff
# Should show: CapEff: 0000003fffffffff (full capabilities)

# Check device access
ls -la /dev/kmsg
# Should exist and be accessible

# Check mount capabilities
mount | grep cgroup
# Should show cgroup mounts
```

### Step 4: Run Deployment
```bash
# Only after all fixes are applied
./deploy.sh hosts.ini
```

## 🔍 DEBUGGING RKE2 STARTUP FAILURES

If RKE2 still fails to start after container fixes:

```bash
# Check service status
systemctl status rke2-server.service

# View detailed logs
journalctl -xeu rke2-server.service --no-pager

# Check configuration
cat /etc/rancher/rke2/config.yaml

# Test manual startup
/usr/local/bin/rke2 server --config=/etc/rancher/rke2/config.yaml
```

## 📋 VERIFICATION CHECKLIST

Before running deployment, verify:

- [ ] LXC container is privileged (`privileged: 1`)
- [ ] Container has nesting and keyctl features enabled
- [ ] AppArmor profile is unconfined
- [ ] br_netfilter module loaded on Proxmox host
- [ ] Container can access /dev/kmsg
- [ ] Container has full capabilities
- [ ] Swap is disabled in container
- [ ] Container has sufficient resources (4+ CPU, 8+ GB RAM)

## ⚠️ SECURITY CONSIDERATIONS

**WARNING**: These changes make LXC containers less secure by:
- Running in privileged mode
- Disabling AppArmor confinement  
- Allowing full device access

This is **required** for Kubernetes but should only be used on trusted infrastructure.

## 🎯 EXPECTED RESULTS AFTER FIXES

After applying these fixes, you should see:
- ✅ Container detected as privileged
- ✅ br_netfilter module loaded
- ✅ No sysctl permission errors  
- ✅ RKE2 service starts successfully
- ✅ Kubernetes API becomes available
