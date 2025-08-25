#!/usr/bin/env bash
set -euo pipefail

# Destroy script for Proxmox LXC containers and storage
# Usage: ./destroy.sh [--confirm]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIRM=false
MAP_FILE="proxmox/vars/lxc_map.yml"

print_usage() {
        cat <<EOF
Usage: $0 [--confirm] [--map <path-to-map.yml>]

Options:
    --confirm            Proceed with destruction without interactive preview prompt
    --map <file>         Path to LXC map file to use. Accepts:
                         • proxmox/vars/....yml (repo-root relative)
                         • vars/....yml (playbook-relative)
                         • absolute path (/.../lxc_map.yml)
                         Default: proxmox/vars/lxc_map.yml

Examples:
    $0                              # Preview using default map, do not destroy
    $0 --map proxmox/vars/lxc_map_lab.yml
    $0 --map vars/lxc_map_lab.yml
    $0 --confirm --map proxmox/vars/lxc_map_lab.yml
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --confirm)
            CONFIRM=true
            shift
            ;;
        --map)
            MAP_FILE="${2:-}"
            if [[ -z "$MAP_FILE" ]]; then
                echo "❌ Missing value for --map"
                print_usage
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            print_usage
            exit 2
            ;;
    esac
done

# Resolve map file to an absolute path usable by Ansible include_vars (playbook-dir relative)
case "$MAP_FILE" in
    /*)
        RESOLVED_MAP_FILE="$MAP_FILE"
        ;;
    proxmox/*)
        # Path relative to repo root
        RESOLVED_MAP_FILE="$PROJECT_ROOT/$MAP_FILE"
        ;;
    vars/*)
        # Path relative to playbook directory (proxmox/)
        RESOLVED_MAP_FILE="$SCRIPT_DIR/$MAP_FILE"
        ;;
    *)
        # Fallback: assume repo-root relative
        RESOLVED_MAP_FILE="$PROJECT_ROOT/$MAP_FILE"
        ;;
esac

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

if [[ "$CONFIRM" != "true" ]]; then
    echo "Current containers that will be destroyed:"
    echo "----------------------------------------"
    
    if command -v ansible >/dev/null 2>&1; then
                # Build ID regex from selected map file (fallback to 101|102|103)
                ID_REGEX="(101|102|103)"
                if [[ -f "$RESOLVED_MAP_FILE" ]]; then
                    # Extract numeric IDs from map
                    IDS=$(awk '/^- id:/ {print $3}' "$RESOLVED_MAP_FILE" | xargs || true)
                    if [[ -n "$IDS" ]]; then
                        # Convert to (id1|id2|id3)
                        IDS_PIPE=$(echo "$IDS" | tr ' ' '|')
                        ID_REGEX="(${IDS_PIPE})"
                    fi
                fi
                # Show what would be destroyed
                ansible all -i "$PROJECT_ROOT/inventories/hosts_proxmox.ini" -m shell -a "pct list | head -1; pct list | grep -E '^${ID_REGEX} ' || echo 'No matching containers found'" --become 2>/dev/null || echo "Could not query containers (ansible not available or hosts unreachable)"
    else
        echo "Ansible not available - cannot preview containers"
    fi
    
    echo
    echo "Configured storage that will be destroyed:"
    echo "------------------------------------------"
    if [[ -f "$RESOLVED_MAP_FILE" ]]; then
        grep -A 10 "mounts:" "$RESOLVED_MAP_FILE" | head -20 || echo "Could not parse $RESOLVED_MAP_FILE"
    else
        echo "$RESOLVED_MAP_FILE not found"
    fi
    
    echo
    echo "To proceed with destruction, run:"
    echo "  $0 --confirm [--map proxmox/vars/lxc_map_lab.yml]"
    echo
    echo "Or manually run the playbook:"
    echo "  ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml -e lxc_map_file='$RESOLVED_MAP_FILE'"
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

# Check if selected map exists
if [[ ! -f "$RESOLVED_MAP_FILE" ]]; then
    echo "❌ Configuration file not found: $RESOLVED_MAP_FILE"
    exit 1
fi

echo "✅ Running destruction playbook..."
echo "📍 Working directory: $PROJECT_ROOT"
echo "🎯 Inventory: inventories/hosts_proxmox.ini"
echo "📋 Playbook: proxmox/destroy-playbook.yml"
echo "🗺️  Map file: $RESOLVED_MAP_FILE"
echo

# Run the destruction playbook
ansible-playbook -i inventories/hosts_proxmox.ini proxmox/destroy-playbook.yml -e "lxc_map_file='$RESOLVED_MAP_FILE'"

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
