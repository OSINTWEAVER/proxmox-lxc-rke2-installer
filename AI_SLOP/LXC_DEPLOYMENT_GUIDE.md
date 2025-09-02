# RKE2 LXC Container Deployment Guide

## Overview
This guide provides enterprise-grade recommendations for deploying RKE2 Kubernetes clusters in LXC containers on Proxmox environments.

## SQLite Mode (Recommended for LXC)

For LXC deployments, we highly recommend using the SQLite datastore mode instead of etcd. This approach provides several benefits:

1. **Avoids etcd/kubelet resource management issues** common in LXC containers
2. **Simplifies deployment** by eliminating etcd-related troubleshooting
3. **Improves stability** in restrictive LXC environments

To enable SQLite mode, add this to your inventory:

```ini
# Enable SQLite mode in your inventory
rke2_use_sqlite=true
```

> **Note**: SQLite mode only supports single-server deployments, not HA clusters. See the complete `SQLITE_MODE_GUIDE.md` for more details.

## LXC Container Requirements

### Container Configuration
```bash
# Recommended LXC container configuration
arch: amd64
cores: 4
memory: 8192
swap: 0
unprivileged: 1
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=XX:XX:XX:XX:XX:XX,ip=dhcp,type=veth
```

### Essential Container Features
```bash
# Required LXC container features for RKE2
features: nesting=1,keyctl=1
```

### Systemd Configuration
LXC containers require specific systemd configurations for optimal RKE2 performance:

```bash
# /etc/systemd/system.conf.d/lxc.conf (auto-configured by role)
[Manager]
DefaultTimeoutStartSec=60s
DefaultTimeoutStopSec=30s
DefaultRestartSec=5s
```

## Network Configuration

### CNI Selection
- **Recommended**: Flannel CNI for LXC containers
- **Avoid**: Canal CNI due to bridge networking limitations

```yaml
# inventory configuration
rke2_cni: [flannel]
```

### Bridge Networking
LXC containers have limited bridge networking capabilities. The role automatically handles:
- Bridge netfilter configuration (with error tolerance)
- IP forwarding settings
- Network policy limitations

## Kernel Module Limitations

### IPVS Support
LXC containers cannot load kernel modules. The role handles this gracefully:
- IPVS module loading fails silently
- Alternative load balancing methods are used
- No impact on cluster functionality

## Storage Considerations

### Local Path Provisioner
Ensure proper mount points for persistent storage:
```bash
# Container mount point configuration
/mnt/data: writable storage path for persistent volumes
```

## Performance Optimizations

### Systemd Service Management
The role includes LXC-specific optimizations:
- Extended service startup timeouts
- Enhanced error recovery mechanisms
- Graceful degradation for restricted operations

### Download Timeouts
Increased timeouts for artifact downloads in containerized environments:
- Checksum downloads: 60 seconds
- Binary downloads: 120 seconds
- Install script: 60 seconds

## Troubleshooting

### Common Issues

#### Service Startup Hangs
- **Symptom**: RKE2 service appears to hang during startup
- **Solution**: Role includes fallback verification and extended timeouts

#### Kernel Module Errors
- **Symptom**: IPVS or bridge module loading failures
- **Solution**: Role gracefully handles module loading failures

#### Systemctl Restrictions
- **Symptom**: systemd operations failing
- **Solution**: Role includes error tolerance and alternative approaches

### Debugging Commands
```bash
# Check container capabilities
lxc-info -n <container-name>

# Verify systemd status
systemctl status rke2-server.service

# Check kernel capabilities
ls /proc/sys/net/bridge/ 2>/dev/null || echo "Bridge modules not available"

# Verify storage access
test -w /mnt/data && echo "Storage writable" || echo "Storage issue"
```

## Security Considerations

### CIS Hardening
- Sysctl configurations may fail silently in LXC
- Role continues deployment despite hardening failures
- Security policies adapted for container limitations

### AppArmor/SELinux
- Container-appropriate security profiles
- Graceful degradation when full security stack unavailable

## Best Practices

1. **Container Resources**: Allocate sufficient CPU/memory for Kubernetes workloads
2. **Storage**: Use dedicated mount points for persistent data
3. **Networking**: Prefer Flannel CNI for simplicity and compatibility
4. **Monitoring**: Implement health checks for containerized services
5. **Backup**: Regular etcd snapshots for cluster state protection

## Compatibility Matrix

| Component | LXC Compatibility | Notes |
|-----------|-------------------|-------|
| RKE2 Core | ✅ Full | All features supported |
| Flannel CNI | ✅ Full | Recommended network plugin |
| Canal CNI | ⚠️ Limited | Bridge networking issues |
| Local Storage | ✅ Full | With proper mount points |
| Load Balancer | ⚠️ Limited | IPVS unavailable, alternatives used |
| CIS Hardening | ⚠️ Partial | Some sysctl settings may fail |

## Support

For LXC-specific issues:
1. Verify container configuration meets requirements
2. Check systemd service status and logs
3. Validate network connectivity between nodes
4. Ensure proper storage mount points

This role has been optimized for enterprise LXC deployments with comprehensive error handling and graceful degradation strategies.
