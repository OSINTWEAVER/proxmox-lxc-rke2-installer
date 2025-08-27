**Create Jumpbox for Infrastructure (WSL Ansible via Powershell)**

```Powershell
# Iris
wsl bash -c "./trust_ssh_hosts.sh inventories/hosts_proxmox.ini"
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_iris_jumpbox.yml"

# Octostar
wsl bash -c "./trust_ssh_hosts.sh inventories/hosts_proxmox.ini"
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar_jumpbox.yml"
```

**Provision LXC Containers for RKE2 (WSL Ansible via Powershell)**

```Powershell
# Iris
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_iris.yml"

# Octostar
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-provision.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar.yml"
```

**Trust Jumpbox for passwordless SSH (Powershell/WSL)**

```Powershell
# Iris
wsl bash -c "./trust_ssh_hosts.sh --user adm4n 10.42.29.100" 
powershell -NoProfile -ExecutionPolicy Bypass -File .\trust_ssh_hosts.ps1 --user adm4n 10.42.29.100

# Octostar
wsl bash -c "./trust_ssh_hosts.sh --user adm4n 10.14.100.100"
powershell -NoProfile -ExecutionPolicy Bypass -File .\trust_ssh_hosts.ps1 --user adm4n 10.14.100.100
```

**SCP Rsync Repo to jumpbox**
```Powershell
# Assumes you are in the root of the repo and overwrites everything in ~/ of the jumpbox with repo everytime you run

# Iris
wsl bash -c "rsync -avz --progress . adm4n@10.42.29.100:/home/adm4n/proxmox-lxc-rke2-installer"

# Octostar
wsl bash -c "rsync -avz --progress . adm4n@10.14.100.100:/home/adm4n/proxmox-lxc-rke2-installer"
```

**Deploy RKE2 (Jumpbox Ansible via WSL)**

```bash
# Iris
wsl bash -c "ssh adm4n@10.42.29.100"
cd ./proxmox-lxc-rke2-installer
./trust_ssh_hosts.sh inventories/hosts-iris.ini
ansible-playbook -i inventories/hosts-iris.ini playbooks/playbook.yml
ansible-playbook -i inventories/hosts-iris.ini playbooks/post_playbook_tools.yml
ansible-playbook -i inventories/hosts-iris.ini playbooks/post_playbook_helm_repos.yml
ansible-playbook -i inventories/hosts-iris.ini playbooks/post_playbook_ingress_migration.yml
ansible-playbook -i inventories/hosts-iris.ini playbooks/post_playbook_storage_config.yml

# Octostar
wsl bash -c "ssh adm4n@10.14.100.100"
cd ./proxmox-lxc-rke2-installer
./trust_ssh_hosts.sh inventories/hosts-octostar.ini
ansible-playbook -i inventories/hosts-octostar.ini playbooks/playbook.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_tools.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_helm_repos.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_ingress_migration.yml
ansible-playbook -i inventories/hosts-octostar.ini playbooks/post_playbook_storage_config.yml

```

**Destroy LXC Containers for RKE2 (WSL Ansible via Powershell)**
```powershell
# This is a full Nuke! But does not destroy the jumpbox

# Iris
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-destroy.yml -e lxc_map_file=proxmox-vars/lxc_map_iris.yml"

# Octostar
wsl bash -c "ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-destroy.yml -e lxc_map_file=proxmox-vars/lxc_map_octostar.yml"
```