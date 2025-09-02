# RKE2 SQLite Mode Deployment Guide

This guide provides instructions for deploying RKE2 in LXC containers using the **fully integrated SQLite datastore mode** instead of etcd. This approach is **strongly recommended** for deployments in LXC containers because:

1. **Eliminates etcd complexity**: Avoids the common etcd/kubelet resource management issues in LXC containers
2. **Improved stability**: Provides a more stable and reliable RKE2 deployment in restrictive LXC environments
3. **Better performance**: Faster startup times and lower resource usage compared to etcd
4. **Simplified troubleshooting**: Single SQLite database file instead of distributed etcd cluster
5. **Full LXC integration**: Includes comprehensive compatibility fixes for LXC containers

## Benefits of the Integrated SQLite Mode

- **Automatic configuration**: Seamlessly integrated into the Ansible deployment process
- **LXC optimizations**: Includes specialized systemd overrides and kubelet configurations
- **Multi-node support**: Single control plane server + multiple worker/agent nodes
- **Production ready**: Enterprise-grade error handling and validation
- **Backwards compatible**: Works with existing inventory configurations

## Prerequisites

- LXC containers set up according to the main guide
- Network connectivity between the containers
- Ansible installed on your control machine

## Deployment Steps

### Step 1: Use the SQLite Inventory Template

1. Copy the SQLite-specific inventory file:

```bash
cp inventories/example-lxc-sqlite.ini inventories/hosts.ini
```

2. Edit the inventory file to match your environment:

```bash
# Edit these values in hosts.ini:
rke2_token=CHANGE-THIS-TO-SECURE-RANDOM-TOKEN   # Generate a secure token
rke2_api_ip=10.14.100.1   # Change to your control plane server IP

# Ensure SQLite mode is enabled:
rke2_use_sqlite=true

# Ensure HA mode is disabled (automatic with SQLite):
rke2_ha_mode=false
```

### Step 2: Deploy the Cluster

Run the standard deployment command:

```bash
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml
```

The deployment will automatically:
- Detect SQLite mode configuration
- Apply LXC-specific optimizations  
- Configure systemd overrides for SQLite mode
- Set up kubelet wrappers for container compatibility
- Initialize the SQLite database
- Deploy worker nodes to join the SQLite-based control plane

## Architecture and Limitations

### Supported Architecture
- **Control Plane**: Single server node running RKE2 with SQLite backend
- **Worker Nodes**: Multiple agent nodes can join the cluster
- **Database**: SQLite database file stored at `/var/lib/rancher/rke2/server/db/state.db`
- **Networking**: Full support for Flannel CNI and standard Kubernetes networking

### Limitations of SQLite Mode

1. **Single Control Plane**: Only supports one control plane server node (no HA)
2. **No etcd Clustering**: Cannot use etcd-based clustering features
3. **Backup Strategy**: Requires SQLite database file backups instead of etcd snapshots
4. **Scale Considerations**: Optimized for smaller to medium clusters

### Performance Characteristics
- **Startup Time**: Significantly faster than etcd initialization
- **Memory Usage**: Lower memory footprint compared to etcd
- **Disk I/O**: Optimized with WAL mode and performance tuning
- **Reliability**: Production-ready with proper SQLite optimizations

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Startup Issues
```bash
# Check RKE2 server status
systemctl status rke2-server

# View detailed logs
journalctl -u rke2-server -f

# Check SQLite database
ls -la /var/lib/rancher/rke2/server/db/
```

#### 2. Agent Node Connection Issues
```bash
# On agent nodes, check connection to SQLite server
systemctl status rke2-agent
journalctl -u rke2-agent -f

# Verify network connectivity to control plane
ping <control-plane-ip>
telnet <control-plane-ip> 9345
```

#### 3. SQLite Database Issues
```bash
# Check database file integrity
sqlite3 /var/lib/rancher/rke2/server/db/state.db ".schema"

# View database size and usage
du -h /var/lib/rancher/rke2/server/db/state.db
```

### Emergency Recovery

If you need to reset and redeploy:

```bash
# Stop services
systemctl stop rke2-server rke2-agent

# Clean up data
rm -rf /var/lib/rancher/rke2/server/db/
rm -rf /etc/rancher/rke2/

# Redeploy with Ansible
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml
```

## Verifying the Deployment

To verify your SQLite-based RKE2 deployment:

```bash
# Export the kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Check control plane node status
/var/lib/rancher/rke2/bin/kubectl get nodes

# Check all pod status across namespaces
/var/lib/rancher/rke2/bin/kubectl get pods -A

# Verify SQLite database is being used
grep -i sqlite /etc/rancher/rke2/config.yaml

# Check database file exists and has content
ls -la /var/lib/rancher/rke2/server/db/state.db

# Use k9s for interactive cluster management
k9s-cluster
```

### Expected Output

If everything is working correctly, you should see:
- Control plane node in `Ready` state
- System pods running in `kube-system` namespace  
- SQLite configuration in the config file
- Active SQLite database file
- Agent nodes (if configured) joining successfully

### Performance Monitoring

Monitor your SQLite-based cluster:

```bash
# Watch cluster resources
watch /var/lib/rancher/rke2/bin/kubectl top nodes

# Monitor database size growth
watch du -h /var/lib/rancher/rke2/server/db/state.db

# Check service health
watch systemctl status rke2-server
```
