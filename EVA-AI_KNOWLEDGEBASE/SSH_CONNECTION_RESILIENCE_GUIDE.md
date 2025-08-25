# SSH Connection Resilience Guide for Ansible Deployments

This guide provides comprehensive solutions for maintaining stable SSH connections during Ansible playbook execution, especially critical for LXC container deployments over potentially unstable networks.

## Enhanced ansible.cfg Configuration (Already Applied)

Your `ansible.cfg` has been optimized with:

### Connection Timeouts
- `timeout = 60` - Overall task timeout (increased from 30s)
- `command_timeout = 60` - Individual command timeout
- `connect_timeout = 30` - Initial connection establishment timeout

### SSH Connection Resilience
- `ControlPersist=300s` - Keep SSH connections alive for 5 minutes (increased from 60s)
- `ServerAliveInterval=60` - Send keepalive every 60 seconds
- `ServerAliveCountMax=3` - Allow 3 missed keepalives before disconnect
- `TCPKeepAlive=yes` - Enable TCP-level keepalives
- `Compression=yes` - Compress data (helps with slow connections)
- `ConnectionAttempts=3` - Retry connection 3 times on failure
- `retries = 3` - Ansible-level retries for failed tasks

### Debugging & Recovery
- `retry_files_enabled = True` - Save failed hosts for retry
- `stdout_callback = yaml` - Better output formatting for debugging

## Environment Variables for Enhanced Resilience

Add these to your shell environment (WSL2) for even better connection stability:

```bash
# Add to ~/.bashrc or ~/.profile in WSL2
export ANSIBLE_SSH_RETRIES=3
export ANSIBLE_TIMEOUT=60
export ANSIBLE_SSH_CONTROL_PATH_DIR=/tmp/.ansible-cp
export ANSIBLE_SSH_PIPELINING=True
export ANSIBLE_PERSISTENT_CONTROL_PATH_DIR=/tmp/.ansible-cp
export ANSIBLE_PARAMIKO_LOOK_FOR_KEYS=False
export ANSIBLE_HOST_KEY_CHECKING=False

# For extremely poor connections, add these:
export ANSIBLE_FORKS=5  # Reduce parallelism to lower network load
export ANSIBLE_GATHER_TIMEOUT=60
```

## Network-Level Optimizations

### 1. WSL2 Network Tuning
```bash
# In WSL2, optimize TCP settings
sudo sysctl -w net.ipv4.tcp_keepalive_time=60
sudo sysctl -w net.ipv4.tcp_keepalive_intvl=10
sudo sysctl -w net.ipv4.tcp_keepalive_probes=3
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
```

### 2. SSH Client Configuration
Create/update `~/.ssh/config` in WSL2:

```
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
    ControlMaster auto
    ControlPath /tmp/.ssh-control-%h-%p-%r
    ControlPersist 300
    ConnectTimeout 30
    ConnectionAttempts 3
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    HashKnownHosts no
    
# Specific optimizations for Proxmox/LXC hosts
Host 10.0.10.* 10.14.100.*
    ServerAliveInterval 30
    ServerAliveCountMax 5
    ConnectTimeout 15
    User root
```

## Deployment Strategy for Poor Connections

### 1. Staged Deployment Approach
Instead of running the full playbook, break it into stages:

```bash
# Stage 1: Basic connectivity and setup
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --tags "basic,connectivity" --limit "iris-node1"

# Stage 2: RKE2 installation per node
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --tags "rke2-install" --limit "iris-node1"
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --tags "rke2-install" --limit "iris-node2"

# Stage 3: Cluster formation
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --tags "cluster"
```

### 2. Connection Testing Script
Create this script to test connections before deployment:

```bash
#!/bin/bash
# test_connections.sh

echo "Testing SSH connections to all hosts..."

for host in $(grep -E "^[0-9]" inventories/hosts.ini | awk '{print $1}'); do
    echo -n "Testing $host: "
    if ssh -o ConnectTimeout=10 -o BatchMode=yes root@$host 'echo "OK"' 2>/dev/null; then
        echo "✅ Connected"
    else
        echo "❌ Failed"
    fi
done
```

### 3. Retry Failed Hosts
If deployment fails, retry only failed hosts:

```bash
# Ansible automatically creates .retry files for failed hosts
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --limit @playbooks/playbook.retry
```

## Task-Level Resilience

### 1. Add Retries to Critical Tasks
For tasks that might fail due to network issues, add retry logic:

```yaml
- name: Download RKE2 installer
  get_url:
    url: "{{ rke2_installer_url }}"
    dest: /tmp/rke2-installer.sh
    mode: '0755'
  retries: 3
  delay: 10
  register: download_result
  until: download_result is succeeded
```

### 2. Network Connectivity Checks
Add connectivity verification tasks:

```yaml
- name: Verify network connectivity
  uri:
    url: "https://github.com/rancher/rke2/releases"
    method: HEAD
    timeout: 30
  retries: 3
  delay: 5
```

## Monitoring Connection Quality

### 1. Real-time Connection Monitoring
Run this in a separate terminal during deployment:

```bash
# Monitor SSH connection multiplexing
watch -n 2 'ls -la /tmp/.ansible-cp/'

# Monitor network connectivity
ping -i 5 10.14.100.1  # Replace with your target IPs
```

### 2. Log Analysis
Enable verbose SSH logging for troubleshooting:

```bash
# Run with SSH debugging
ansible-playbook -vvv -i inventories/hosts.ini playbooks/playbook.yml

# Or set environment variable
export ANSIBLE_SSH_ARGS="-vvv"
```

## Emergency Recovery Procedures

### 1. If Connections Keep Dropping
```bash
# Reset SSH control connections
rm -rf /tmp/.ansible-cp/*
rm -rf /tmp/.ssh-control-*

# Clear SSH known hosts
rm -f ~/.ssh/known_hosts

# Restart with reduced parallelism
export ANSIBLE_FORKS=1
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml
```

### 2. If Specific Hosts Are Problematic
```bash
# Skip problematic hosts temporarily
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --limit "!iris-node2"

# Or run only on working hosts
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml --limit "iris-node1,iris-node3"
```

### 3. Network Quality Testing
```bash
# Test bandwidth and latency to LXC hosts
iperf3 -c 10.14.100.1 -t 10
mtr --report --report-cycles 100 10.14.100.1
```

## WSL2 Specific Optimizations

### 1. WSL2 Network Bridge Fix
If experiencing WSL2 network issues:

```bash
# In PowerShell (as Administrator)
netsh winsock reset
netsh int ip reset

# Restart WSL2
wsl --shutdown
wsl
```

### 2. Windows Firewall/VPN Considerations
- Ensure Windows Firewall allows WSL2 traffic
- If using VPN, ensure split tunneling for local Proxmox network
- Consider temporarily disabling Windows Defender real-time protection during deployment

## Best Practices Summary

1. **Always test connectivity first** with the test script
2. **Use staging approach** for large deployments
3. **Monitor connection quality** during deployment
4. **Keep retry files** for failed host recovery
5. **Use verbose logging** when troubleshooting
6. **Reduce parallelism** on poor connections
7. **Enable TCP keepalives** at multiple levels
8. **Use SSH connection multiplexing** effectively

These optimizations should significantly improve deployment reliability over poor or unstable network connections.
