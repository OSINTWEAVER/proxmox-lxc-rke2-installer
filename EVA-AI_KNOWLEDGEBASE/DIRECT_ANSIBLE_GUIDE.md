# Direct Ansible Deployment Guide 🎯

## Quick Start (Core Cluster)

```bash
# Deploy core RKE2 cluster 
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml
```

## Enhanced Deployment (Core + Add-ons)

```bash
# 1. Deploy core cluster first
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml

# 2. Add enhanced components after cluster is ready
ansible-playbook -i inventories/hosts.ini playbooks/post-deployment-enhanced.yml
```

## Configuration Options

Set these variables in your inventory file or pass as extra-vars:

### Core Cluster Options:
```bash
# SQLite mode (single server)
--extra-vars "rke2_use_sqlite=true"

# HA mode (multiple servers) 
--extra-vars "rke2_ha_mode=true"

# Custom RKE2 version
--extra-vars "rke2_version=v1.32.7+rke2r1"
```

### Post-Deployment Add-ons:
```bash
# Enable specific components
--extra-vars "install_management_tools=true"
--extra-vars "rke2_ingress_nginx_enabled=true" 
--extra-vars "use_local_path_provisioner=true"
--extra-vars "install_rancher=true"
```

## Common Deployment Scenarios

### Scenario 1: Minimal Cluster
```bash
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml \
  --extra-vars "rke2_use_sqlite=true"
```

### Scenario 2: HA Cluster with Storage
```bash
# Core cluster
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml \
  --extra-vars "rke2_ha_mode=true"

# Add storage provisioner
ansible-playbook -i inventories/hosts.ini playbooks/post-deployment-enhanced.yml \
  --extra-vars "use_local_path_provisioner=true"
```

### Scenario 3: Full Platform with Rancher UI
```bash
# Core cluster
ansible-playbook -i inventories/hosts.ini playbooks/playbook.yml

# Full enhanced stack
ansible-playbook -i inventories/hosts.ini playbooks/post-deployment-enhanced.yml \
  --extra-vars "rke2_ingress_nginx_enabled=true" \
  --extra-vars "use_local_path_provisioner=true" \
  --extra-vars "install_rancher=true"
```

## Verification Commands

```bash
# Check cluster status
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes

# Check all pods
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods --all-namespaces

# Check storage classes
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get storageclass
```

## Benefits of Direct Ansible

- ✅ **No wrapper scripts** - Direct, transparent execution
- ✅ **Full control** - All Ansible features available 
- ✅ **Better debugging** - Native Ansible output and error handling
- ✅ **CI/CD friendly** - Easy to integrate into automation pipelines
- ✅ **Professional** - Industry standard approach
