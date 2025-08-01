# Proxmox LXC Container Setup for RKE2 Cluster

## Overview

This cheat sheet provides step-by-step instructions for creating LXC containers on Proxmox for an RKE2 Kubernetes cluster with the following architecture:

| Container ID | Hostname | IP Address | Role | Resources | Storage |
|--------------|-----------|------------|------|-----------|---------|
| 100 | os-env-ansible-1 | 10.14.100.10 | Ansible Control | 2GB RAM, 2 CPU | 20GB Root |
| 101 | os-env-cp-1 | 10.14.100.1 | Control Plane | 4GB RAM, 2 CPU | 20GB Root |
| 102 | os-env-gpu-1 | 10.14.100.2 | GPU Worker | 96GB RAM, 12 CPU | 20GB Root + 3TB Data |
| 103 | os-env-gpu-2 | 10.14.100.3 | GPU Worker | 96GB RAM, 12 CPU | 20GB Root + 3TB Data |

**Network**: VLAN 14, Bridge vmbr0, Subnet 10.14.1.1/16

---

## 1. Container Creation Commands

### Create Ansible Control Container (ID 100)
```bash
# Create LXC container (DO NOT start yet - AppArmor setup needed first)
pct create 100 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-ansible-1 \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,gw=10.14.1.1,ip=10.14.100.10/16,tag=14,type=veth \
  --ostype ubuntu \
  --rootfs local-lvm:20 \
  --unprivileged 0
```

### Create Control Plane Container (ID 101)
```bash
# Create LXC container (DO NOT start yet - AppArmor setup needed first)
pct create 101 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-cp-1 \
  --memory 4096 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,gw=10.14.1.1,ip=10.14.100.1/16,tag=14,type=veth \
  --ostype ubuntu \
  --rootfs local-lvm:20 \
  --unprivileged 0
```

### Create GPU Worker Container 1 (ID 102)
```bash
# Create ZFS volume for data storage (3TB thin-provisioned)
zfs create -V 3T -s temp-pool/vm-102-data

# Create LXC container (DO NOT start yet - AppArmor setup needed first)
pct create 102 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-gpu-1 \
  --memory 98304 \
  --cores 12 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,gw=10.14.1.1,ip=10.14.100.2/16,tag=14,type=veth \
  --ostype ubuntu \
  --rootfs local-lvm:20 \
  --unprivileged 0
```

### Create GPU Worker Container 2 (ID 103)
```bash
# Create ZFS volume for data storage (3TB thin-provisioned)
zfs create -V 3T -s temp-pool/vm-103-data

# Create LXC container (DO NOT start yet - AppArmor setup needed first)
pct create 103 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-gpu-2 \
  --memory 98304 \
  --cores 12 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,gw=10.14.1.1,ip=10.14.100.3/16,tag=14,type=veth \
  --ostype ubuntu \
  --rootfs local-lvm:20 \
  --unprivileged 0
```

---

## 2. Configure Container Security Profiles

Before starting any containers, we need to relax security profiles for proper operation:

### Configure All Containers for RKE2 Compatibility
```bash
# Ansible control container (unprivileged)
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/100.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/100.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/100.conf

# Control plane container (unprivileged)  
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/101.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/101.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/101.conf

# GPU containers (privileged for GPU passthrough)
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/102.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/102.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/102.conf

echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/103.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/103.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/103.conf
```

### Mount Data Volumes and Start Containers
```bash
# Mount data volumes for GPU containers (after they're created but before starting)
mkfs.ext4 /dev/zvol/temp-pool/vm-102-data
mkfs.ext4 /dev/zvol/temp-pool/vm-103-data

pct set 102 --mp0 /dev/zvol/temp-pool/vm-102-data,mp=/mnt/data
pct set 103 --mp0 /dev/zvol/temp-pool/vm-103-data,mp=/mnt/data

# Now start all containers
pct start 100
pct start 101  
pct start 102
pct start 103
```

---

## 3. Verify Container Creation
```bash
# Check container status
pct list

# Expected output:
# VMID NAME                STATUS     LOCK  
# 100  os-env-ansible-1    running          
# 101  os-env-cp-1         running          
# 102  os-env-gpu-1        running          
# 103  os-env-gpu-2        running
```

---

## 4. GPU Passthrough Configuration (for GPU containers only)

### Enable NVIDIA Passthrough for os-env-gpu-1 (Container 102)
```bash
pct stop 102
cat <<EOF >> /etc/pve/nodes/$(hostname)/lxc/102.conf
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 507:* rwm
lxc.cgroup2.devices.allow: c 511:* rwm
lxc.mount.entry: /dev/nvidia0                 dev/nvidia0                 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl               dev/nvidiactl               none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm              dev/nvidia-uvm              none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools        dev/nvidia-uvm-tools        none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file
EOF
pct start 102
```

### Enable NVIDIA Passthrough for os-env-gpu-2 (Container 103)
```bash
pct stop 103
cat <<EOF >> /etc/pve/nodes/$(hostname)/lxc/103.conf
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 507:* rwm
lxc.cgroup2.devices.allow: c 511:* rwm
lxc.mount.entry: /dev/nvidia0                 dev/nvidia0                 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl               dev/nvidiactl               none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm              dev/nvidia-uvm              none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools        dev/nvidia-uvm-tools        none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file
EOF
pct start 103
```

---

## 5. Container Setup & Configuration

### Verify Network Connectivity (all containers)
```bash
# Test basic connectivity before package installation
pct exec 100 -- ping -c 2 8.8.8.8
pct exec 101 -- ping -c 2 8.8.8.8
pct exec 102 -- ping -c 2 8.8.8.8  
pct exec 103 -- ping -c 2 8.8.8.8

# Test DNS resolution
pct exec 100 -- nslookup archive.ubuntu.com
pct exec 101 -- nslookup archive.ubuntu.com
pct exec 102 -- nslookup archive.ubuntu.com
pct exec 103 -- nslookup archive.ubuntu.com
```

### Disable UFW (all containers)
```bash
pct exec 100 -- ufw disable || true
pct exec 101 -- ufw disable || true
pct exec 102 -- ufw disable || true
pct exec 103 -- ufw disable || true
```

### Update Ubuntu & Install Essentials (all containers)
```bash
# Ansible control container
pct exec 100 -- bash -c 'apt update && apt -y full-upgrade && apt -f install'
pct exec 100 -- bash -c 'apt install -y build-essential curl vim gnupg lsb-release unzip sudo ca-certificates software-properties-common p7zip-full git python3 python3-pip python3-venv ansible sshpass rsync nginx'

# Control plane container
pct exec 101 -- bash -c 'apt update && apt -y full-upgrade && apt -f install'
pct exec 101 -- bash -c 'apt install -y build-essential curl vim gnupg lsb-release unzip sudo ca-certificates software-properties-common p7zip-full git python3 python3-pip python3-venv'

# GPU containers
pct exec 102 -- bash -c 'apt update && apt -y full-upgrade && apt -f install'
pct exec 102 -- bash -c 'apt install -y build-essential curl vim gnupg lsb-release unzip sudo ca-certificates software-properties-common p7zip-full git python3 python3-pip python3-venv'

pct exec 103 -- bash -c 'apt update && apt -y full-upgrade && apt -f install'
pct exec 103 -- bash -c 'apt install -y build-essential curl vim gnupg lsb-release unzip sudo ca-certificates software-properties-common p7zip-full git python3 python3-pip python3-venv'
```

### Configure UTF-8 Locale (all containers)
```bash
# Ansible control
pct exec 100 -- bash -c 'apt install -y locales && sed -i "s/^# *en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && locale-gen && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8'

# Control plane
pct exec 101 -- bash -c 'apt install -y locales && sed -i "s/^# *en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && locale-gen && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8'

# GPU containers
pct exec 102 -- bash -c 'apt install -y locales && sed -i "s/^# *en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && locale-gen && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8'

pct exec 103 -- bash -c 'apt install -y locales && sed -i "s/^# *en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen && locale-gen && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8'
```

### Create adm4n User (all containers)
```bash
# Ansible control - Clean up and recreate user properly
pct exec 100 -- bash -c 'userdel -r adm4n 2>/dev/null || true'
pct exec 100 -- adduser --disabled-password --gecos "" adm4n
pct exec 100 -- bash -c 'echo "adm4n:3rgoD0x!" | chpasswd'
pct exec 100 -- usermod -aG sudo adm4n
pct exec 100 -- bash -c 'visudo -c -f /etc/sudoers && echo "adm4n ALL=(ALL) NOPASSWD:ALL" | EDITOR="tee" visudo -f /etc/sudoers.d/adm4n'
pct exec 100 -- bash -c 'chown root:root /etc/sudoers.d/adm4n && chmod 440 /etc/sudoers.d/adm4n'
pct exec 100 -- bash -c 'chown -R adm4n:adm4n /home/adm4n && chmod 755 /home/adm4n'
pct exec 100 -- bash -c 'mkdir -p /home/adm4n/.ssh && chown adm4n:adm4n /home/adm4n/.ssh && chmod 700 /home/adm4n/.ssh'

# Control plane - Clean up and recreate user properly
pct exec 101 -- bash -c 'userdel -r adm4n 2>/dev/null || true'
pct exec 101 -- adduser --disabled-password --gecos "" adm4n
pct exec 101 -- bash -c 'echo "adm4n:3rgoD0x!" | chpasswd'
pct exec 101 -- usermod -aG sudo adm4n
pct exec 101 -- bash -c 'visudo -c -f /etc/sudoers && echo "adm4n ALL=(ALL) NOPASSWD:ALL" | EDITOR="tee" visudo -f /etc/sudoers.d/adm4n'
pct exec 101 -- bash -c 'chown root:root /etc/sudoers.d/adm4n && chmod 440 /etc/sudoers.d/adm4n'
pct exec 101 -- bash -c 'chown -R adm4n:adm4n /home/adm4n && chmod 755 /home/adm4n'
pct exec 101 -- bash -c 'mkdir -p /home/adm4n/.ssh && chown adm4n:adm4n /home/adm4n/.ssh && chmod 700 /home/adm4n/.ssh'

# GPU container 1 - Clean up and recreate user properly
pct exec 102 -- bash -c 'userdel -r adm4n 2>/dev/null || true'
pct exec 102 -- adduser --disabled-password --gecos "" adm4n
pct exec 102 -- bash -c 'echo "adm4n:3rgoD0x!" | chpasswd'
pct exec 102 -- usermod -aG sudo adm4n
pct exec 102 -- bash -c 'visudo -c -f /etc/sudoers && echo "adm4n ALL=(ALL) NOPASSWD:ALL" | EDITOR="tee" visudo -f /etc/sudoers.d/adm4n'
pct exec 102 -- bash -c 'chown root:root /etc/sudoers.d/adm4n && chmod 440 /etc/sudoers.d/adm4n'
pct exec 102 -- bash -c 'chown -R adm4n:adm4n /home/adm4n && chmod 755 /home/adm4n'
pct exec 102 -- bash -c 'mkdir -p /home/adm4n/.ssh && chown adm4n:adm4n /home/adm4n/.ssh && chmod 700 /home/adm4n/.ssh'

# GPU container 2 - Clean up and recreate user properly
pct exec 103 -- bash -c 'userdel -r adm4n 2>/dev/null || true'
pct exec 103 -- adduser --disabled-password --gecos "" adm4n
pct exec 103 -- bash -c 'echo "adm4n:3rgoD0x!" | chpasswd'
pct exec 103 -- usermod -aG sudo adm4n
pct exec 103 -- bash -c 'visudo -c -f /etc/sudoers && echo "adm4n ALL=(ALL) NOPASSWD:ALL" | EDITOR="tee" visudo -f /etc/sudoers.d/adm4n'
pct exec 103 -- bash -c 'chown root:root /etc/sudoers.d/adm4n && chmod 440 /etc/sudoers.d/adm4n'
pct exec 103 -- bash -c 'chown -R adm4n:adm4n /home/adm4n && chmod 755 /home/adm4n'
pct exec 103 -- bash -c 'mkdir -p /home/adm4n/.ssh && chown adm4n:adm4n /home/adm4n/.ssh && chmod 700 /home/adm4n/.ssh'
```

### Fix sudo ownership issues (run if still having problems)
```bash
# Fix sudo ownership in all containers
pct exec 100 -- bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'
pct exec 100 -- bash -c 'chown root:root /etc/sudo.conf && chown root:root /etc/sudoers'

pct exec 101 -- bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'
pct exec 101 -- bash -c 'chown root:root /etc/sudo.conf && chown root:root /etc/sudoers'

pct exec 102 -- bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'
pct exec 102 -- bash -c 'chown root:root /etc/sudo.conf && chown root:root /etc/sudoers'

pct exec 103 -- bash -c 'chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo'
pct exec 103 -- bash -c 'chown root:root /etc/sudo.conf && chown root:root /etc/sudoers'
```

### Install Docker (all containers)
```bash
# Ansible control container
pct exec 100 -- bash -c '
  apt-get install -y ca-certificates curl gnupg lsb-release && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce docker-ce-cli containerd.io && \
  docker run hello-world
'

# Control plane container
pct exec 101 -- bash -c '
  apt-get install -y ca-certificates curl gnupg lsb-release && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce docker-ce-cli containerd.io && \
  docker run hello-world
'

# GPU containers
pct exec 102 -- bash -c '
  apt-get install -y ca-certificates curl gnupg lsb-release && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce docker-ce-cli containerd.io && \
  docker run hello-world
'

pct exec 103 -- bash -c '
  apt-get install -y ca-certificates curl gnupg lsb-release && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  apt-get install -y docker-ce docker-ce-cli containerd.io && \
  docker run hello-world
'
```

### Install NVIDIA Driver in GPU Containers (REQUIRED before Container Toolkit)
**Note**: You must have the NVIDIA driver .run file saved on your Proxmox host (e.g., `~/NVIDIA-Linux-x86_64-575.64.05.run`)

```bash
# Transfer NVIDIA driver installer to GPU containers
pct push 102 ~/NVIDIA-Linux-x86_64-575.64.05.run ~/NVIDIA-Linux-x86_64-575.64.05.run
pct push 103 ~/NVIDIA-Linux-x86_64-575.64.05.run ~/NVIDIA-Linux-x86_64-575.64.05.run

# Install NVIDIA driver in GPU container 1
pct exec 102 -- bash -c '
  chmod +x ~/NVIDIA-Linux-x86_64-575.64.05.run && \
  ~/NVIDIA-Linux-x86_64-575.64.05.run --dkms --no-questions --ui=none --no-kernel-module --no-drm --install-libglvnd && \
  ldconfig
'

# Install NVIDIA driver in GPU container 2
pct exec 103 -- bash -c '
  chmod +x ~/NVIDIA-Linux-x86_64-575.64.05.run && \
  ~/NVIDIA-Linux-x86_64-575.64.05.run --dkms --no-questions --ui=none --no-kernel-module --no-drm --install-libglvnd && \
  ldconfig
'
```

### Test NVIDIA Driver Installation
```bash
# Test nvidia-smi in both GPU containers
echo "Testing NVIDIA driver installation..."
pct exec 102 -- nvidia-smi
pct exec 103 -- nvidia-smi

# If successful, you should see GPU information tables
# If you see "command not found" or device errors, check:
# 1. GPU passthrough configuration (step 4)
# 2. Driver file path and permissions
# 3. Host NVIDIA driver compatibility
```

### Install NVIDIA Container Toolkit (GPU containers only)
```bash
# GPU container 1
pct exec 102 -- bash -c '
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
  apt update && \
  apt install -y nvidia-container-toolkit && \
  nvidia-ctk runtime configure --runtime=docker && \
  systemctl restart docker
'

# GPU container 2
pct exec 103 -- bash -c '
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
  apt update && \
  apt install -y nvidia-container-toolkit && \
  nvidia-ctk runtime configure --runtime=docker && \
  systemctl restart docker
'
```

### Create Nginx Smoke Test (Ansible container)
```bash
pct exec 100 -- bash -c '
cat <<HTML > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>RKE2 Ansible Control - Smoke Test</title>
  <style>
    body { background:#111; color:#0f0; font-family:monospace; text-align:center; padding-top:10%; }
    h1 { font-size: 2.5em; }
    p { font-size: 1.2em; margin: 0.4em 0; }
  </style>
</head>
<body>
  <h1>RKE2 Ansible Control Ready</h1>
  <p>Host: $(hostname)</p>
  <p>IP Address: $(hostname -I | awk "{print \$1}")</p>
  <p>Server Time: $(date)</p>
  <p>Uptime: $(uptime -p)</p>
</body>
</html>
HTML
'
pct exec 100 -- systemctl restart nginx
```

### Comprehensive Testing & Smoke Tests
```bash
# Test basic Docker functionality on all containers
echo "Testing Docker installation..."
pct exec 100 -- docker run hello-world
pct exec 101 -- docker run hello-world
pct exec 102 -- docker run hello-world  
pct exec 103 -- docker run hello-world

# Test NVIDIA driver access in GPU containers
echo "Testing NVIDIA driver access..."
pct exec 102 -- nvidia-smi
pct exec 103 -- nvidia-smi

# Test NVIDIA Container Toolkit integration (GPU containers only)
echo "Testing GPU Docker integration..."
pct exec 102 -- docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
pct exec 103 -- docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi

# If the above commands show GPU information tables from inside Docker containers,
# your GPU passthrough and container toolkit are working correctly!
```

### Test Ansible Container Web Interface
Browse to `http://10.14.100.10` to verify the Nginx smoke test page loads.

### Optional: Install nvtop for GPU Monitoring
```bash
# Install nvtop for real-time GPU monitoring (GPU containers only)
pct exec 102 -- apt install -y nvtop
pct exec 103 -- apt install -y nvtop

# Test nvtop (press Ctrl+C to exit)
pct exec 102 -- timeout 5 nvtop || echo "nvtop test completed"
pct exec 103 -- timeout 5 nvtop || echo "nvtop test completed"
```

---

## 6. Transition to PC-Based Management

At this point, all containers are configured and accessible. Rather than continuing with `pct exec` commands on the Proxmox hosts, we'll transition to working directly from your PC via SSH to the ansible container.

### Transfer RKE2 Installer from PC to Ansible Container
```powershell
# From Visual Studio Code terminal in the root of your rke2-installer repo
# Create archive excluding unnecessary files
tar -czf rke2-installer.tar.gz --exclude=".git" --exclude="kubeconfs" --exclude="*.tar.gz" .

# Transfer to ansible container
scp -o StrictHostKeyChecking=no rke2-installer.tar.gz adm4n@10.14.100.10:/home/adm4n/

# SSH into the ansible container
ssh adm4n@10.14.100.10
```

### Setup RKE2 Installer on Ansible Container
```bash
# Now working inside the ansible container via SSH from your PC
# Extract the installer
cd /home/adm4n
tar -xzf rke2-installer.tar.gz
cd rke2-installer

# Install Ansible Galaxy requirements
ansible-galaxy install -r requirements.yml

# Verify Ansible installation
ansible --version
```

### Setup SSH Keys for Cluster Access
```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Display public key for distribution
cat ~/.ssh/id_ed25519.pub
```

### Distribute SSH Key to Target Containers
From your PC (open new PowerShell terminal in VS Code), facilitate the SSH key distribution:

```powershell
# Get the public key from ansible container
ssh adm4n@10.14.100.10 "cat ~/.ssh/id_ed25519.pub" > ansible_key.pub

# Distribute to each target container
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.1:/tmp/
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.2:/tmp/
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.3:/tmp/

# Install the key on each target container
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.1 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.2 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.3 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"

# Clean up
rm ansible_key.pub
```

### Test SSH Connectivity
```bash
# Back in your SSH session to the ansible container (10.14.100.10)
# Test passwordless SSH to all nodes
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.1 "hostname && exit"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.2 "hostname && exit"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.3 "hostname && exit"
```

---

## 7. Troubleshooting: Fixing sudo on Containers 100 & 101

If you encounter `sudo: ... owned by uid 100000, should be 0` errors on containers 100 and 101, it indicates a UID mapping issue, likely because they were created as unprivileged. The most reliable fix is to destroy and recreate them as privileged containers.

### Step 1: Destroy the problematic containers
```bash
# Stop and destroy the containers
pct stop 100 && pct destroy 100
pct stop 101 && pct destroy 101
```

### Step 2: Recreate containers 100 and 101 as privileged
```bash
# Recreate Ansible Control Container (ID 100) - PRIVILEGED
pct create 100 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-ansible-1 \
  --unprivileged 0 \
  --net0 name=eth0,bridge=vmbr0,ip=10.14.100.10/16,gw=10.14.1.1 \
  --memory 2048 --cores 2 --rootfs local-lvm:20

# Recreate Control Plane Container (ID 101) - PRIVILEGED
pct create 101 /var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname os-env-cp-1 \
  --unprivileged 0 \
  --net0 name=eth0,bridge=vmbr0,ip=10.14.100.1/16,gw=10.14.1.1 \
  --memory 4096 --cores 2 --rootfs local-lvm:40
```

### Step 3: Apply Security Profiles and Start
```bash
# Apply RKE2 compatibility settings
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/100.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/100.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/100.conf

echo "lxc.apparmor.profile: unconfined" >> /etc/pve/nodes/$(hostname)/lxc/101.conf
echo "lxc.cgroup2.devices.allow: a"       >> /etc/pve/nodes/$(hostname)/lxc/101.conf
echo "lxc.cap.drop:"                      >> /etc/pve/nodes/$(hostname)/lxc/101.conf

# Start the new containers
pct start 100
pct start 101
```

### Step 4: Re-run Initial Setup
After recreating the containers, you must re-run the setup steps from section **5. Container Setup & Configuration** for containers 100 and 101. This includes:
- Disabling UFW
- Updating Ubuntu & installing essentials
- Configuring the locale
- Creating the `adm4n` user

This process ensures that the containers are built on a correct, privileged foundation, which will resolve the `sudo` ownership errors permanently.

---

## 8. Transition to PC-Based Management
```powershell
# From Visual Studio Code terminal in the root of your rke2-installer repo
# Create archive excluding unnecessary files
tar -czf rke2-installer.tar.gz --exclude=".git" --exclude="kubeconfs" --exclude="*.tar.gz" .

# Transfer to ansible container
scp -o StrictHostKeyChecking=no rke2-installer.tar.gz adm4n@10.14.100.10:/home/adm4n/

# SSH into the ansible container
ssh adm4n@10.14.100.10
```

### Setup RKE2 Installer on Ansible Container
```bash
# Now working inside the ansible container via SSH from your PC
# Extract the installer
cd /home/adm4n
tar -xzf rke2-installer.tar.gz
cd rke2-installer

# Install Ansible Galaxy requirements
ansible-galaxy install -r requirements.yml

# Verify Ansible installation
ansible --version
```

### Setup SSH Keys for Cluster Access
```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Display public key for distribution
cat ~/.ssh/id_ed25519.pub
```

### Distribute SSH Key to Target Containers
From your PC (open new PowerShell terminal in VS Code), facilitate the SSH key distribution:

```powershell
# Get the public key from ansible container
ssh adm4n@10.14.100.10 "cat ~/.ssh/id_ed25519.pub" > ansible_key.pub

# Distribute to each target container
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.1:/tmp/
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.2:/tmp/
scp -o StrictHostKeyChecking=no ansible_key.pub adm4n@10.14.100.3:/tmp/

# Install the key on each target container
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.1 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.2 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.3 "cat /tmp/ansible_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm /tmp/ansible_key.pub"

# Clean up
rm ansible_key.pub
```

### Test SSH Connectivity
```bash
# Back in your SSH session to the ansible container (10.14.100.10)
# Test passwordless SSH to all nodes
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.1 "hostname && exit"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.2 "hostname && exit"
ssh -o StrictHostKeyChecking=no adm4n@10.14.100.3 "hostname && exit"
```

---

## 9. Configure Ansible Inventory and SSH Access

### Edit Inventory Configuration
```bash
# Still working in the ansible container via SSH from your PC
# Edit the existing inventory file (already configured)
nano inventories/hosts.ini
```

**The inventory should already be configured correctly:**
```ini
[rke2_cluster:children]
rke2_servers
rke2_agents

[rke2_servers]
10.14.100.1 ansible_user=adm4n rke2_type=server

[rke2_agents]
10.14.100.2 ansible_user=adm4n rke2_type=agent
10.14.100.3 ansible_user=adm4n rke2_type=agent

[rke2_cluster:vars]
# Basic cluster configuration
rke2_token=my-super-secret-token-change-me
rke2_api_ip=10.14.100.1
rke2_version=v1.30.6+rke2r1

# Network configuration for VLAN 14
cluster_cidr=10.42.0.0/16
service_cidr=10.43.0.0/16
cluster_dns=10.43.0.10

# Configurable naming (maintains backward compatibility)
node_name_prefix=os-env-
gpu_node_pattern=gpu

# Rancher UI installation
install_rancher=true
rancher_hostname=rancher.local
rancher_bootstrap_password=admin123

# Storage configuration
local_path_provisioner_path=/mnt/data
```

### Test Ansible Connectivity
```bash
# Test connection to all hosts using the existing inventory
ansible -i inventories/hosts.ini all -m ping

# Expected output should show SUCCESS for all three hosts:
# 10.14.100.1 | SUCCESS => {"ping": "pong"}
# 10.14.100.2 | SUCCESS => {"ping": "pong"}
# 10.14.100.3 | SUCCESS => {"ping": "pong"}
```

### Deploy RKE2 Cluster
```bash
# Run the deployment using the existing inventory
./deploy.sh hosts.ini

# The deployment will:
# 1. Prepare all systems (configure networking, disable swap if present, etc.)
# 2. Install RKE2 on control plane and workers
# 3. Configure Cilium CNI
# 4. Install local-path-provisioner for storage
# 5. Install NVIDIA GPU Operator (for GPU nodes)
# 6. Install Rancher UI (if enabled)
# 7. Download kubeconfig to kubeconfs/hosts.yaml
```

---

## 10. Post-Deployment Access and Management

### From Your PC
```powershell
# Download the kubeconfig from ansible container
scp adm4n@10.14.100.10:/home/adm4n/rke2-installer/kubeconfs/hosts.yaml ./kubeconfig-hosts.yaml

# Use kubectl from your PC (if kubectl is installed)
kubectl --kubeconfig=kubeconfig-hosts.yaml get nodes
```

### From Ansible Container
```bash
# SSH back into ansible container
ssh adm4n@10.14.100.10
cd rke2-installer

# Access cluster using downloaded kubeconfig
export KUBECONFIG=/home/adm4n/rke2-installer/kubeconfs/hosts.yaml
kubectl get nodes
kubectl get pods --all-namespaces

# Check GPU nodes specifically
kubectl get nodes -l "node.kubernetes.io/instance-type=gpu" 2>/dev/null || kubectl get nodes
```

### Access Rancher UI
- **URL**: http://10.14.100.1:30080 or https://10.14.100.1:30443
- **Username**: admin
- **Password**: admin123 (as configured in inventory)

### Verify GPU Support (if GPU nodes exist)
```bash
# Check if NVIDIA GPU Operator is running
kubectl get pods -n gpu-operator-resources
kubectl get nodes -o wide

# Test GPU access on a GPU node
ssh adm4n@10.14.100.2 "nvidia-smi" 2>/dev/null || echo "No GPU detected on this node"
ssh adm4n@10.14.100.3 "nvidia-smi" 2>/dev/null || echo "No GPU detected on this node"
```

---

## 11. Troubleshooting Multi-Host Setup

### Network Connectivity Issues
```bash
# Test inter-container communication from ansible container
ping 10.14.100.1
ping 10.14.100.2
ping 10.14.100.3

# If ping fails, check VLAN configuration on Proxmox hosts
# Ensure all containers are on VLAN 14 with bridge vmbr0
```

### SSH Key Issues
```bash
# Re-distribute SSH keys if needed
ssh-copy-id -i ~/.ssh/id_ed25519.pub adm4n@10.14.100.1
ssh-copy-id -i ~/.ssh/id_ed25519.pub adm4n@10.14.100.2
ssh-copy-id -i ~/.ssh/id_ed25519.pub adm4n@10.14.100.3

# Or manually test SSH access
ssh -vvv adm4n@10.14.100.1
```

### Configure Passwordless Sudo (Required for Ansible)
```bash
# Configure passwordless sudo on all target nodes
# This is required for RKE2 installation automation
for host in 10.14.100.1 10.14.100.2 10.14.100.3; do
    ssh adm4n@$host "echo 'adm4n ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/adm4n"
    ssh adm4n@$host "sudo chmod 440 /etc/sudoers.d/adm4n"
    echo "Configured passwordless sudo on $host"
done

# Test sudo access (should not prompt for password)
ssh adm4n@10.14.100.1 "sudo whoami"  # Should return "root"
ssh adm4n@10.14.100.2 "sudo whoami"  # Should return "root"
ssh adm4n@10.14.100.3 "sudo whoami"  # Should return "root"
```

### Container Resource Issues
```bash
# Check if containers have adequate resources
ssh adm4n@10.14.100.1 "free -h && df -h"
ssh adm4n@10.14.100.2 "free -h && df -h"
ssh adm4n@10.14.100.3 "free -h && df -h"
```

### Ansible Deployment Issues
```bash
# Run Ansible with verbose output
ansible -i inventories/hosts.ini all -m ping -vvv

# Check system preparation
ansible -i inventories/hosts.ini all -m shell -a "systemctl is-active systemd-resolved"
ansible -i inventories/hosts.ini all -m shell -a "swapon --show"
```

---

## 12. Quick Reference Commands

### From Your PC (Windows PowerShell in VS Code)
```powershell
# Connect to ansible container
ssh adm4n@10.14.100.10

# Transfer files to ansible container
scp file.txt adm4n@10.14.100.10:/home/adm4n/

# Download kubeconfig
scp adm4n@10.14.100.10:/home/adm4n/rke2-installer/kubeconfs/hosts.yaml ./

# Quick cluster status check
ssh adm4n@10.14.100.10 "export KUBECONFIG=/home/adm4n/rke2-installer/kubeconfs/hosts.yaml && kubectl get nodes"
```

### From Ansible Container
```bash
# Deploy cluster (make executable first)
chmod +x deploy.sh
./deploy.sh hosts.ini

# Check cluster status
export KUBECONFIG=/home/adm4n/rke2-installer/kubeconfs/hosts.yaml
kubectl get nodes
kubectl get pods --all-namespaces

# Access specific nodes
ssh adm4n@10.14.100.1
ssh adm4n@10.14.100.2
ssh adm4n@10.14.100.3

# Check Rancher status
kubectl get pods -n cattle-system
```

### Common Maintenance Tasks
```bash
# Update cluster configuration
nano inventories/hosts.ini
chmod +x deploy.sh
./deploy.sh hosts.ini

# Scale workers (add new agent IPs to inventory)
ansible -i inventories/hosts.ini rke2_agents -m ping

# Backup kubeconfig
cp kubeconfs/hosts.yaml kubeconfs/hosts-backup-$(date +%Y%m%d).yaml
```

---

## Summary

This cheat sheet provides a complete workflow for:

1. **LXC Container Creation**: Multi-host Proxmox setup with proper networking
2. **GPU Passthrough**: NVIDIA device mounting for GPU workloads
3. **Ansible Management**: Dedicated control container for cluster automation
4. **PC-Based Workflow**: Seamless transition from Proxmox host to PC management
5. **SSH Key Distribution**: Reliable multi-host key deployment
6. **RKE2 Deployment**: Complete Kubernetes cluster with Cilium, GPU support, and Rancher UI
7. **Troubleshooting**: Common issues and their solutions

The setup is production-ready and follows proven methodologies for enterprise Kubernetes deployments on Proxmox LXC infrastructure.

### Key Benefits
- **Containerized Approach**: Faster than VMs, direct kernel sharing
- **GPU Support**: Native NVIDIA GPU passthrough for AI/ML workloads
- **Scalable Storage**: ZFS thin provisioning with dedicated data volumes
- **Enterprise Networking**: VLAN segmentation for secure cluster communication
- **Automated Deployment**: Ansible-driven RKE2 installation with minimal manual intervention
- **Management Flexibility**: Control from PC while containers run on Proxmox infrastructure
