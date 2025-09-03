# RKE2 Nuclear Uninstall Playbook

## ⚠️ DANGER ZONE ⚠️

This playbook **COMPLETELY DESTROYS** your RKE2 cluster and removes **EVERYTHING** related to Kubernetes/RKE2.

## What it does

### Phase 1: Stop Services
- Stops and disables all RKE2 services (rke2-server, rke2-agent, k3s, etc.)
- Kills all related processes with extreme prejudice

### Phase 2: Remove Data
- Deletes `/var/lib/rancher` (complete RKE2 data)
- Removes `/etc/rancher` (configurations)
- Cleans `/var/lib/kubelet`, `/run/k3s`, `/run/rke2`
- Removes all CNI and network configurations

### Phase 3: Network Cleanup
- Removes all CNI network interfaces
- Cleans up iptables rules
- Removes network namespaces
- Resets network configurations

### Phase 4: System Cleanup
- Removes systemd service files and overrides
- Deletes all Kubernetes tools (kubectl, helm, k9s)
- Cleans up user configurations and kubeconfigs
- Removes aliases from user profiles

### Phase 5: Package Removal
- Uninstalls all RKE2/Kubernetes packages
- Removes container runtimes
- Cleans up helm installations

### Phase 6: Extreme Force (optional)
- When `force_level: 'extreme'` - finds and removes ANY file/directory with "rke2", "k3s", or "kube" in the name

## Usage

### For Octostar cluster:
```bash
# With confirmation prompt (recommended first time)
ansible-playbook -i inventories/hosts-octostar_actual.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml

# Skip confirmation (for automation)
ansible-playbook -i inventories/hosts-octostar_actual.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml -e skip_confirmation=true

# Extreme force mode (maximum destruction)
ansible-playbook -i inventories/hosts-octostar_actual.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml -e force_level=extreme
```

### For Iris cluster:
```bash
ansible-playbook -i inventories/hosts-iris.ini playbooks/troubleshooting/rke2_nuclear_uninstall.yml
```

## Variables

- `force_level`: Set to `'extreme'` for maximum destruction (default: `'extreme'`)
- `skip_confirmation`: Set to `true` to skip the safety confirmation prompt (default: `true`)

## Safety Features

- **Confirmation prompt** by default (unless `skip_confirmation=true`)
- **Failed tasks don't stop execution** - uses `failed_when: false` and `ignore_errors: true`
- **Comprehensive logging** - shows what was removed
- **Verification step** - confirms complete removal

## What survives

This playbook is designed to be thorough, but some things may remain:
- Your Ansible inventory files
- The playbook itself
- System packages not related to Kubernetes
- User accounts and SSH keys
- Network interface configurations (eth0, etc.)

## After running

Once complete, you can:
1. Run a fresh RKE2 installation
2. No conflicts or leftover configurations
3. Clean slate for troubleshooting

## Recovery

If you need to recover data:
- This playbook removes everything - no recovery possible
- Use Proxmox snapshots for backup/restore
- Keep backups of important data before running

## Example Output

```
⚠️  WARNING: This will COMPLETELY DESTROY your RKE2 cluster!

This playbook will:
- Stop and disable all RKE2 services
- Kill all RKE2 and Kubernetes processes
- Remove ALL RKE2 data and configurations
- Clean up network configurations
- Remove kubectl, helm, k9s, and all tools
- Delete user configurations and kubeconfigs
- Remove systemd overrides and custom configurations

This is IRREVERSIBLE. Make sure you have backups if needed.

Type 'YES' to continue or 'NO' to abort:
```

## Final Warning

**USE WITH EXTREME CAUTION**

This playbook is designed for development/testing environments where you need to start completely fresh. It will destroy your cluster without mercy.

Make sure you have:
- Proxmox snapshots for quick recovery
- Backups of any important data
- Understanding that this is completely irreversible
