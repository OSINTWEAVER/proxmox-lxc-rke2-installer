# WSL2 Run Guide: Proxmox LXC RKE2 Provisioning

This guide shows how to run the Proxmox provisioning from Windows using WSL2 (Ubuntu). It covers prerequisites, configuration, and execution.

## Prerequisites

- Windows 11 with WSL2 (Ubuntu recommended)
- Git installed in WSL2
- Ansible installed in WSL2
- SSH key in WSL2 at `~/.ssh/id_ed25519.pub` (or generate one)
- Network access from WSL2 to your Proxmox hosts
- Proxmox 8.x hosts reachable by IP and root login enabled

Optional GPU support prerequisites:
- NVIDIA driver `.run` file present on the relevant Proxmox host(s), e.g. `/root/NVIDIA-Linux-x86_64-575.64.05.run`

## Setup

1) Clone repo (if not already):
- In WSL2 shell, go to a working directory and clone:

```
git clone https://github.com/OSINTWEAVER/proxmox-lxc-rke2-installer.git
cd proxmox-lxc-rke2-installer
```

2) Prepare Proxmox inventory:
- Copy `inventories/hosts_proxmox_template.ini` to `inventories/hosts_proxmox.ini` and edit to match your Proxmox hosts.

3) Configure LXC map:
- Default map file used by the playbooks is `proxmox/vars/lxc_map.yml`.
- Copy `proxmox/vars/lxc_map_template.yml` to `proxmox/vars/lxc_map.yml` and edit (or create variants like `lxc_map_lab.yml`, `lxc_map_prod.yml`):
  - Set `ssh.username` and `ssh.password`
  - Set `storage_defaults` or per-mount overrides
  - Mark `gpu: true` for GPU nodes and set `nvidia.driver_host_path` globally or per node
  - Adjust container IPs, resources, and mounts as needed

4) Trust SSH keys on Proxmox hosts and LXC nodes (optional helper):
- From WSL2, run the helper script to push your SSH key to Proxmox and later the nodes.
  - For Proxmox hosts:

```
bash ./trust_ssh_hosts.sh proxmox 10.0.10.8 10.0.10.1 10.0.10.2
```

This script uses `sshpass` and will prompt for the root password of the provided hosts once.

## Run

Default (uses `proxmox/vars/lxc_map.yml`):

```
ansible-playbook -i inventories/hosts_proxmox.ini proxmox/proxmox-playbook.yml
```

Use a different map (e.g., `proxmox/vars/lxc_map_lab.yml`):

```
ansible-playbook -i inventories/hosts_proxmox.ini proxmox/proxmox-playbook.yml -e lxc_map_file=proxmox/vars/lxc_map_lab.yml
```

What it does:
- Loads required kernel modules; persists them
- Prepares storage mounts (ZFS zvols or directories)
- Creates LXC containers with proper net, rootfs, and mounts
- Applies Kubernetes-friendly LXC security settings
- Starts containers if needed
- Creates the SSH admin user inside each container with sudo NOPASSWD
- If `gpu: true` and an NVIDIA driver path is set, pushes the `.run` file into the container at `nvidia.driver_dest_path`

## After provisioning

- Optionally run the trust script again for the new containers to install your WSL2 public key to the `adm4n` user:

```
bash ./trust_ssh_hosts.sh nodes 10.14.100.1 10.14.100.2 10.14.100.3
```

- Proceed with the main cluster deployment using the repository README instructions.

## Tips
- You can mix mount types: `zfs_volume`, `directory`, and `lvm_lv` (stub). For `directory`, ensure the host path exists.
- To use a different ZFS pool per host or node, set `pool` on the specific mount.
- Passwords are kept out of version control by ignoring `proxmox/vars/lxc_map*.yml` (template remains tracked).

Selecting a different map (summary)
- Provision:
  - ansible-playbook -i inventories/hosts_proxmox.ini proxmox/proxmox-playbook.yml -e lxc_map_file=proxmox/vars/lxc_map_lab.yml
- Destroy:
  - ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml -e lxc_map_file=proxmox/vars/lxc_map_lab.yml

Destroying with a different map
- Quick helper script (now supports --map):
  - Preview: `bash proxmox/destroy.sh --map proxmox/vars/lxc_map_lab.yml`
  - Confirmed: `bash proxmox/destroy.sh --confirm --map proxmox/vars/lxc_map_lab.yml`
- Or run the playbook directly:
  - ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml -e lxc_map_file=proxmox/vars/lxc_map_lab.yml

Beginner-friendly flow (example)
1) Copy template to your default map and edit it:
  - `cp proxmox/vars/lxc_map_template.yml proxmox/vars/lxc_map.yml`
2) Provision using the default map:
  - `ansible-playbook -i inventories/hosts_proxmox.ini proxmox/proxmox-playbook.yml`
3) Later, create a lab variant and use it:
  - `cp proxmox/vars/lxc_map.yml proxmox/vars/lxc_map_lab.yml` (edit as needed)
  - Provision: `ansible-playbook -i inventories/hosts_proxmox.ini proxmox/proxmox-playbook.yml -e lxc_map_file=proxmox/vars/lxc_map_lab.yml`
  - Destroy: `bash proxmox/destroy.sh --confirm --map proxmox/vars/lxc_map_lab.yml`

Securing secrets with Ansible Vault (optional)
- Option A: Encrypt the entire map file
  - ansible-vault encrypt proxmox/vars/lxc_map_prod.yml
  - You’ll be prompted for a vault password when running the playbook.
- Option B: Keep a separate encrypted secrets file and reference from your map
  - ansible-vault create proxmox/vars/lxc_secrets.yml
  - In your map, reference values via Jinja, for example:
    - `password: "{{ lxc_secrets.proxmox_password }}"`
  - Load the secrets alongside your map:
    - ansible-playbook ... -e lxc_map_file=proxmox/vars/lxc_map_lab.yml -e @proxmox/vars/lxc_secrets.yml
