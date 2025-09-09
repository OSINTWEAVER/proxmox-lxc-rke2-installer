# Proxmox LXC RKE2 Installer - Quick Reference

## 🔐 Trust Proxmox Hosts

```Powershell
# Trust Proxmox hosts for SSH access
wsl bash -c "./trust_ssh_hosts.sh inventories/hosts_proxmox.ini"
```

## 🔧 Host Setup

### Download Ubuntu Templates
```Powershell
# Download Ubuntu 22.04 LTS template to all Proxmox hosts
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-template-download-ubuntu2204.yml"
```

### NVIDIA Drivers
```Powershell
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-nvidia-driver-install.yml -e nvidia_driver_version=580.82.07"
```

## 🚀 Infrastructure Setup

### Create Jumpbox
```Powershell
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_my_lab.yml"
```

### Provision LXC Containers
```Powershell
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_my_lab.yml"
```

## 🔐 SSH Configuration

### Trust Jumpbox
```Powershell
wsl bash -c "./trust_ssh_hosts.sh --user myuser 10.0.0.100"
powershell -NoProfile -ExecutionPolicy Bypass -File .\trust_ssh_hosts.ps1 --user myuser 10.0.0.100
```

### SCP Rsync Repo to Jumpbox
```Powershell
wsl bash -c "rsync -avz --progress . myuser@10.0.0.100:/home/myuser/proxmox-lxc-rke2-installer"
```

## ☸️ Kubernetes Deployment

### Deploy RKE2
```bash
wsl bash -c "ssh myuser@10.0.0.100"
cd ./proxmox-lxc-rke2-installer
ansible-galaxy collection install -r requirements-collections.yml
./trust_ssh_hosts.sh inventories/hosts-my-lab.ini
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/playbook.yml
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/post_playbook_tools.yml
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/post_playbook_helm_repos.yml
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/post_playbook_simple_storage_test.yml
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/post_playbook_domain_ssl_config.yml -e domain=example.com
```

## 📥 Cluster Access

### Fetch Kubeconfig
```powershell
.\scripts\fetch_kubeconfig.bat inventories\hosts-my-lab.ini
```

## 🗑️ Cleanup & Destruction

### Nuclear RKE2 Uninstall
```bash
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml -e skip_confirmation=true
```

### Destroy LXC Containers
```powershell
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-destroy.yml -e lxc_map_file=proxmox-vars/lxc_map_my_lab.yml"
```

## 🛠️ Troubleshooting

### Storage Issues
```bash
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/troubleshooting/fix_storage.yml
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/troubleshooting/simple_storage_test.yml
```

### Install Rancher Only
```bash
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/troubleshooting/install_rancher_only.yml
```

### Install Ansible Collections
```bash
ansible-playbook -i inventories/hosts-my-lab.ini playbooks/utils/install-ansible-collections.yml
```
