# Rancher UI Installation Troubleshooting

## Overview

This playbook provides an alternative method to install the Rancher Management UI when the standard installation fails or gets stuck.

## When to Use

Use this playbook when:
- Standard Rancher installation fails
- Rancher UI installation gets stuck during deployment
- You need to reinstall Rancher on an existing cluster
- The `cattle-system` namespace is in a bad state

## Usage

```bash
# Install Rancher management UI (alternative method)
ansible-playbook -i inventories/hosts-your-cluster.ini playbooks/troubleshooting/install_rancher_only.yml
```

## What It Does

1. **Cleanup Phase**: Forces deletion of stuck `cattle-system` namespace if it exists
2. **Wait Phase**: Ensures namespace cleanup is complete before proceeding
3. **Installation Phase**: Installs Rancher using Helm with proper configurations
4. **Verification Phase**: Confirms Rancher pods are running and accessible

## Variables

- `rancher_hostname`: The hostname for Rancher UI (default: `rancher.local`)
- `rancher_bootstrap_password`: Bootstrap password for Rancher (optional)
- `admin_user`: Admin username for the cluster (default: `adm4n`)

## Requirements

- RKE2 cluster must be running and accessible
- `kubectl` must be available and configured
- Helm must be installed on the control plane node</content>
<parameter name="filePath">d:\dev\proxmox-lxc-rke2-installer\playbooks\troubleshooting\README_install_rancher_only.md
