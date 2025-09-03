# Proxmox LXC RKE2 Installer - Quick Reference

## 📋 Updates

### September 2025 - DNS Resolution & Nuclear Uninstall
- **DNS Fix**: Resolved DNS resolution failures in helm-operation pods by removing hardcoded `rke2_cluster_dns` values (10.41.0.10) from the main playbook. The playbook now respects inventory-specific DNS settings (e.g., 10.43.0.10 for Octostar).
- **Nuclear Uninstall Playbook**: Added `playbooks/troubleshooting/rke2_nuclear_uninstall.yml` for complete RKE2 cluster destruction with 10 phases of cleanup, including service stops, process kills, data removal, and network cleanup.
- **DNS Repair Post-Playbook**: Created `playbooks/troubleshooting/post_playbook_dns_repair.yml` for automated DNS fixes on existing clusters with clusterDNS mismatches.
- **Enhanced Domain SSL Config**: Updated `post_playbook_domain_ssl_config.yml` to automatically detect and support both upstream ingress-nginx and RKE2 ingress-nginx controllers.
- **Deprecated Ingress Migration**: Removed `post_playbook_ingress_migration.yml` from workflows as it's no longer needed with the enhanced SSL configuration.

> **📁 Organization**: Troubleshooting and fix playbooks are located in `playbooks/troubleshooting/`, and utility playbooks are in `playbooks/utils/` for better organization and maintenance.

> **⚙️ MTU Configuration**: Network MTU is now configurable in the `proxmox-vars/*.yml` files. Set `mtu: 9000` for jumbo frames (high-speed networks) or `mtu: 1500` for standard networks.

## 🚀 Infrastructure Setup

### Create Jumpbox for Infrastructure (WSL Ansible via Powershell)

```Powershell
# Octostar
wsl bash -c "./trust_ssh_hosts.sh inventories/hosts_proxmox.ini"
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar_jumpbox.yml"
```

### Provision LXC Containers for RKE2 (WSL Ansible via Powershell)

```Powershell
# Octostar
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar.yml"
```

## 🔧 Advanced Features

### Setup RDMA/InfiniBand on Proxmox Hosts

```Powershell
# Setup RDMA support on Proxmox hosts (requires manual RDMA link creation afterwards)
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox_host_soft_rdma_setup.yml"

# MANUAL STEP REQUIRED after running the above:
# Create RDMA links based on your network interface configuration
# Example: rdma link add rxe0 type rxe netdev <your_interface>
# Replace <your_interface> with your actual network interface (e.g., bond0, eth0, etc.)

# Fix networking if RDMA setup breaks connectivity
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/troubleshooting/proxmox_rdma_network_fix.yml"

# Complete RDMA removal - uninstalls packages, removes configs, fixes networking
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/troubleshooting/proxmox_rdma_complete_removal.yml"

# Nuclear option: Reboot Proxmox hosts to fix persistent networking issues
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/troubleshooting/proxmox_reboot_fix.yml"
```

## 🔐 SSH Configuration

### Trust Jumpbox for passwordless SSH (Powershell/WSL)

```Powershell
# Octostar
wsl bash -c "./trust_ssh_hosts.sh --user adm4n 10.14.100.100"
powershell -NoProfile -ExecutionPolicy Bypass -File .\trust_ssh_hosts.ps1 --user adm4n 10.14.100.100
```

### SCP Rsync Repo to jumpbox
```Powershell
# Assumes you are in the root of the repo and overwrites everything in ~/ of the jumpbox with repo everytime you run

# Octostar
wsl bash -c "rsync -avz --progress . adm4n@10.14.100.100:/home/adm4n/proxmox-lxc-rke2-installer"

```

## ☸️ Kubernetes Deployment

### Deploy RKE2 (Jumpbox Ansible via WSL)

```bash
# Octostar
wsl bash -c "ssh adm4n@10.14.100.100"
cd ./proxmox-lxc-rke2-installer
./trust_ssh_hosts.sh inventories/hosts-octostar.ini
ansible-playbook -i inventories/hosts-octostar.ini playbooks/playbook.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_tools.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_helm_repos.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_simple_storage_test.yml

```

## 🛠️ Troubleshooting & Fixes

### Fix Rancher Installation Issues (Jumpbox Ansible via WSL)

```bash
# If Rancher installation fails with "cannot re-use a name that is still in use"

# Octostar  
ansible-playbook -i inventories/hosts-octostar.ini playbooks/troubleshooting/fix_rancher_installation.yml
```


## 📥 Cluster Access

```bash
# Octostar
wsl bash -c "ssh adm4n@10.14.100.100"
cd ./proxmox-lxc-rke2-installer
./trust_ssh_hosts.sh inventories/hosts-octostar.ini
ansible-playbook -i inventories/hosts-octostar.ini playbooks/playbook.yml
### Fetch Kubeconfig (Windows/WSL)

```powershell
# Octostar
.\scripts\fetch_kubeconfig.bat inventories\hosts-octostar.ini
```

## 🗑️ Cleanup & Destruction

### Nuclear RKE2 Uninstall (Complete Cluster Destruction)

```bash
# WARNING: This will completely destroy your RKE2 cluster and all data!
# Use with extreme caution - this is for fresh reinstalls only

# Octostar Cluster
ansible-playbook -i inventories/hosts-octostar.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml -e skip_confirmation=true

# Generic cluster (replace with your inventory file)
ansible-playbook -i inventories/hosts-your-cluster.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml -e skip_confirmation=true
```

**What this does:**
- Stops all RKE2 services
- Kills all related processes
- Removes all RKE2 data directories
- Cleans network configurations
- Removes RKE2 packages
- Provides verification of complete cleanup

**Use this when:**
- You need a completely clean slate for cluster reinstallation
- Previous installations have left behind conflicting configurations
- You want to ensure no residual data affects new deployments

### Destroy LXC Containers for RKE2 (WSL Ansible via Powershell)
```powershell
# This is a full Nuke! But does not destroy the jumpbox

# Octostar
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-destroy.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar.yml"
```