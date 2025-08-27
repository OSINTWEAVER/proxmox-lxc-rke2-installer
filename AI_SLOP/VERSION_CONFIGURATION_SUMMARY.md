# Version Configuration Summary

## Overview
All hardcoded version references have been moved to configurable variables in the inventory files. This allows easy version management and upgrades without editing multiple files.

## Changes Made

### 1. Inventory Files Updated
- **`inventories/template.ini`**: Added comprehensive version configuration section
- **`inventories/hosts.ini`**: Added version variables matching template

### 2. New Configurable Variables

```ini
# Core versions
rke2_version=v1.32.7+rke2r1
kubernetes_version=v1.32.7

# Component versions (for reference and documentation)
etcd_version=v3.5.21-k3s1
containerd_version=v2.0.5-k3s2
runc_version=v1.2.6
metrics_server_version=v0.8.0
coredns_version=v1.12.2
ingress_nginx_version=v1.12.4-hardened2
helm_controller_version=v0.16.13
```

### 3. Files Modified to Use Variables

#### `playbooks/playbook.yml`
- ✅ RKE2 version: Now uses `{{ rke2_version | default('v1.32.7+rke2r1') }}`
- ✅ kubectl download: Now uses `{{ kubernetes_version | default('v1.32.7') }}`
- ✅ Cluster info: Dynamic version display

#### `ansible-role-rke2/defaults/main.yml`
- ✅ RKE2 version: Uses inventory variable with fallback

#### `ansible-role-rke2/tasks/rancher.yml`
- ✅ Task description: Generic version compatibility statement

#### `ansible-role-rke2/tasks/lxc_fixes.yml`
- ✅ Comments: Dynamic version references
- ✅ Success message: Uses variable-based version display

#### `ansible-role-rke2/molecule/default/converge.yml`
- ✅ Test configuration: Uses variable with fallback

## Version Compatibility Matrix

### RKE2 v1.32.7+rke2r1 (Current Configuration)
- **Kubernetes**: v1.32.7
- **Etcd**: v3.5.21-k3s1
- **Containerd**: v2.0.5-k3s2
- **Rancher Compatibility**: ✅ Full support
- **CNI Options**: Canal (Flannel v0.27.1 + Calico v3.30.2), Calico v3.30.1, Cilium v1.17.6, Multus v4.2.1

### Upgrade Path Examples

#### To upgrade to newer RKE2 version:
1. Update `rke2_version` in inventory file
2. Update `kubernetes_version` to match
3. Update component versions as needed
4. Redeploy cluster

#### Example for RKE2 v1.33.3+rke2r1:
```ini
rke2_version=v1.33.3+rke2r1
kubernetes_version=v1.33.3
# Note: May require Rancher chart compatibility checks
```

## Benefits

1. **Centralized Version Management**: All versions in one place (inventory files)
2. **Easy Upgrades**: Change versions in inventory, redeploy
3. **Version Consistency**: kubectl matches RKE2's Kubernetes version automatically
4. **Documentation**: Component versions clearly documented
5. **Flexibility**: Different environments can use different versions
6. **Maintenance**: No more hunting through multiple files for version references

## Usage

### For New Deployments
1. Copy `inventories/template.ini` to `inventories/hosts.ini`
2. Customize version variables as needed
3. Update node IP addresses
4. Deploy with `./deploy.sh hosts.ini`

### For Version Changes
1. Edit version variables in your inventory file
2. Ensure Kubernetes version matches RKE2's bundled version
3. Check Rancher compatibility if using Rancher
4. Redeploy or upgrade cluster

## Rancher Compatibility Notes

- **RKE2 v1.32.7+rke2r1**: ✅ Compatible with Rancher 2.11.x charts
- **RKE2 v1.33.x+rke2r1**: ⚠️ May require newer Rancher charts or `--disable-openapi-validation`

## Testing

All version changes should be tested with:
1. Cluster deployment
2. Rancher installation (if enabled)
3. Basic workload deployment
4. kubectl/helm functionality

---

**Current Status**: All hardcoded versions removed ✅  
**Next Step**: Ready for cluster redeployment with v1.32.7+rke2r1
