# NVIDIA Driver Installation for Proxmox Infrastructure

## Overview

This repository provides comprehensive NVIDIA driver installation for both Proxmox hosts and LXC containers, with unified version management through the inventory configuration.

## Components

### 1. Proxmox Host Driver Installation
- **Playbook**: `playbooks/proxmox-nvidia-driver-install.yml`
- **Purpose**: Install NVIDIA drivers directly on Proxmox hosts
- **Use Case**: GPU passthrough, host-level GPU access

### 2. LXC Container Driver Installation  
- **Playbooks**: `playbooks/proxmox-provision.yml` and `playbooks/proxmox-provision_with_soft_rdma.yml`
- **Purpose**: Install NVIDIA drivers inside GPU-enabled LXC containers
- **Use Case**: Container-based GPU workloads

## Configuration

### Unified Version Management
The NVIDIA driver version is configured in `inventories/hosts_proxmox.ini`:

```ini
[all:vars]
nvidia_driver_version=580.82.07
```

This version is used by:
- ✅ Host driver installation (`proxmox-nvidia-driver-install.yml`)
- ✅ Container driver installation (both provision playbooks)
- ✅ Automatic driver downloads from NVIDIA's official repository

## Features

### Host Installation
- ✅ **Smart Detection**: Checks if NVIDIA drivers are already working
- ✅ **Nouveau Blacklisting**: Automatically creates blacklist configuration if needed
- ✅ **Automatic Reboots**: Handles required reboots intelligently
- ✅ **Driver Compilation**: Installs all required packages for DKMS compilation
- ✅ **Cleanup**: Removes old NVIDIA packages before installation
- ✅ **Verification**: Tests driver installation with nvidia-smi

### Container Installation  
- ✅ **Direct Download**: Downloads drivers directly into containers (no file pushing)
- ✅ **Container-Optimized**: Uses appropriate flags for LXC environments
- ✅ **Version Consistency**: Uses same version as configured in inventory
- ✅ **Dependency Management**: Installs build tools and headers
- ✅ **Error Handling**: Graceful failure with detailed error messages

## Usage

### Basic Installation

```bash
# Install NVIDIA drivers on all Proxmox hosts
ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-nvidia-driver-install.yml
```

### Custom Driver Version

```bash
# Install specific driver version
ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-nvidia-driver-install.yml -e nvidia_driver_version=550.90.07
```

### Target Specific Hosts

```bash
# Install on specific hosts only
ansible-playbook -i inventories/hosts_proxmox.ini playbooks/proxmox-nvidia-driver-install.yml --limit "10.0.10.1,10.0.10.2"
```

## Configuration

The driver version is configured in `inventories/hosts_proxmox.ini`:

```ini
[all:vars]
nvidia_driver_version=580.82.07
```

## Process Flow

1. **Pre-Check**: Test if nvidia-smi already works
2. **Nouveau Blacklist**: Create blacklist configuration if missing
3. **First Reboot**: Reboot if nouveau blacklist was created
4. **Package Installation**: Install build tools and kernel headers
5. **Driver Download**: Download NVIDIA driver from official source
6. **Cleanup**: Remove existing NVIDIA packages
7. **Driver Installation**: Install new driver with DKMS support
8. **Second Reboot**: Reboot after driver installation
9. **Verification**: Test nvidia-smi functionality
10. **Cleanup**: Remove downloaded driver file

## Requirements

- Proxmox hosts running Debian
- Internet connectivity for driver download
- Sufficient disk space for driver compilation
- NVIDIA hardware present in the system

## Safety Features

- Only creates nouveau blacklist if it doesn't exist
- Only reboots when necessary
- Comprehensive error checking and reporting
- Graceful handling of already-installed drivers
- Detailed installation summary

## Troubleshooting

### Driver Installation Failed

1. Check if NVIDIA hardware is present: `lspci | grep -i nvidia`
2. Verify kernel headers are installed: `dpkg -l | grep pve-headers`
3. Check for conflicting packages: `dpkg -l | grep nvidia`
4. Review installation logs in the playbook output

### System Won't Boot After Installation

1. Boot into recovery mode
2. Remove nouveau blacklist: `rm /etc/modprobe.d/blacklist-nouveau.conf`
3. Update initramfs: `update-initramfs -u -k all`
4. Reboot and retry installation

## Supported Driver Versions

- Latest Production Branch: 580.x series
- Latest New Feature Branch: 550.x series  
- Legacy Support: Check NVIDIA's official compatibility list

## Post-Installation

After successful installation:

1. Verify GPU detection: `nvidia-smi`
2. Check driver version: `nvidia-smi --query-gpu=driver_version --format=csv`
3. Test GPU functionality with your specific workloads
4. Configure GPU passthrough if needed for LXC containers

## Notes

- The playbook uses DKMS for automatic kernel module rebuilding
- Driver is installed with `--disable-nouveau` for safety
- Installation is performed in non-interactive mode
- Original driver file is automatically cleaned up after installation
