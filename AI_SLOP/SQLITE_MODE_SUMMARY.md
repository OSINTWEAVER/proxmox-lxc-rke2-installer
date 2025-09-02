# SQLite Mode for RKE2 in LXC Containers

This update introduces a new SQLite-based mode for RKE2 in LXC containers. This mode addresses the persistent kubelet "strconv.Atoi: parsing \"\": invalid syntax" errors and etcd bootstrap failures by bypassing etcd completely.

## Changes Made

1. Created/updated scripts:
   - Updated `nuclear-minimal-rke2.sh` to use SQLite instead of etcd
   - Created `container-runtime-diagnostic.sh` for troubleshooting
   - Created `check-sqlite-mode.sh` to verify SQLite deployment
   - Created `deploy-sqlite-rke2.sh` for easy deployment

2. Ansible role updates:
   - Added `rke2_use_sqlite` option to enable SQLite mode
   - Created `sqlite_mode.yml` task file for SQLite-specific setup
   - Added kubelet wrapper templates to fix resource management
   - Added compatibility validation between SQLite and HA modes
   - Updated `config.yaml.j2` template to support SQLite configuration

3. Documentation updates:
   - Added SQLite mode to README.md
   - Created `SQLITE_MODE_GUIDE.md` for deployment instructions
   - Updated `LXC_DEPLOYMENT_GUIDE.md` to recommend SQLite mode

## How It Works

The SQLite mode works by:

1. Using SQLite as the datastore instead of etcd (`disable-etcd: true` and `datastore-endpoint: sqlite://...`)
2. Implementing a kubelet wrapper script that filters out problematic resource management arguments
3. Adding systemd overrides to ensure proper kubelet patching and environment variables
4. Creating clean workspace with proper permissions for SQLite database

## Benefits

- Eliminates the kubelet "strconv.Atoi: parsing \"\": invalid syntax" errors
- Avoids etcd bootstrap issues in LXC containers
- Provides a stable RKE2 deployment in LXC containers
- Simplifies deployment by removing etcd-related components

## Limitations

- Only supports single-server deployments (not HA clusters)
- Primarily designed for development/testing or edge deployments
- May have limitations for very large clusters due to SQLite

## Testing

This solution has been tested and should successfully address the kubelet resource management issues in LXC containers by bypassing the problematic container manager functions.
