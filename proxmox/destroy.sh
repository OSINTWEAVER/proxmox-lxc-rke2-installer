#!/usr/bin/env bash
set -euo pipefail

# Destroy script for Proxmox LXC containers and storage
# Usage: ./destroy.sh [--confirm]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIRM_FLAG=${1:-}

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          🔥 DESTRUCTION PLAYBOOK 🔥                          ║"
echo "║                                                                              ║"
echo "║  This will PERMANENTLY DESTROY all LXC containers and storage volumes       ║"
echo "║  defined in your lxc_map.yml configuration file.                            ║"
echo "║                                                                              ║"
echo "║  What will be destroyed:                                                     ║"
echo "║    • All LXC containers (forceful stop + destroy)                           ║"
echo "║    • ZFS volumes (3TB+ data volumes)                                        ║"
echo "║    • Directory mounts and their contents                                    ║"
echo "║    • Container configuration files                                           ║"
echo "║                                                                              ║"
echo "║  ⚠️  THIS CANNOT BE UNDONE! ALL DATA WILL BE LOST! ⚠️                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

if [[ "$CONFIRM_FLAG" != "--confirm" ]]; then
    echo "Current containers that will be destroyed:"
    echo "----------------------------------------"
    
    if command -v ansible >/dev/null 2>&1; then
        # Show what would be destroyed
        ansible all -i "$PROJECT_ROOT/inventories/hosts_proxmox.ini" -m shell -a "pct list | head -1; pct list | grep -E '^(101|102|103) ' || echo 'No matching containers found'" --become 2>/dev/null || echo "Could not query containers (ansible not available or hosts unreachable)"
    else
        echo "Ansible not available - cannot preview containers"
    fi
    
    echo
    echo "Configured storage that will be destroyed:"
    echo "------------------------------------------"
    if [[ -f "$SCRIPT_DIR/vars/lxc_map.yml" ]]; then
        grep -A 10 "mounts:" "$SCRIPT_DIR/vars/lxc_map.yml" | head -20 || echo "Could not parse lxc_map.yml"
    else
        echo "lxc_map.yml not found"
    fi
    
    echo
    echo "To proceed with destruction, run:"
    echo "  $0 --confirm"
    echo
    echo "Or manually run the playbook:"
    echo "  ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml"
    exit 0
fi

echo "🔥 PROCEEDING WITH DESTRUCTION..."
echo

cd "$PROJECT_ROOT"

# Check if ansible is available
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "❌ ansible-playbook not found. Please install Ansible first."
    exit 1
fi

# Check if inventory exists
if [[ ! -f "inventories/hosts_proxmox.ini" ]]; then
    echo "❌ Inventory file not found: inventories/hosts_proxmox.ini"
    exit 1
fi

# Check if lxc_map.yml exists
if [[ ! -f "proxmox/vars/lxc_map.yml" ]]; then
    echo "❌ Configuration file not found: proxmox/vars/lxc_map.yml"
    exit 1
fi

echo "✅ Running destruction playbook..."
echo "📍 Working directory: $PROJECT_ROOT"
echo "🎯 Inventory: inventories/hosts_proxmox.ini"
echo "📋 Playbook: proxmox/destroy-playbook.yml"
echo

# Run the destruction playbook
ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml

echo
echo "🔥 Destruction playbook completed!"
echo
echo "Summary of actions:"
echo "  • Stopped all matching LXC containers"
echo "  • Destroyed container instances"
echo "  • Cleaned up ZFS volumes"
echo "  • Removed directory mounts"
echo "  • Cleaned up configuration files"
echo
echo "Your Proxmox hosts should now be clean and ready for fresh deployment."
