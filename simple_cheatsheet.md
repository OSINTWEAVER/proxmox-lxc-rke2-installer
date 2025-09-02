# Proxmox LXC RKE2 Installer - Quick Reference

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
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_ingress_migration.yml
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

### Destroy LXC Containers for RKE2 (WSL Ansible via Powershell)
```powershell
# This is a full Nuke! But does not destroy the jumpbox

# Octostar
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-destroy.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar.yml"
```