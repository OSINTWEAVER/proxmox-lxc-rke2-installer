# LXC Fixes Conflict Resolution Summary

## Overview
Review of `ansible-role-rke2/tasks/lxc_fixes.yml` to identify and resolve conflicts with the main RKE2 deployment, particularly with SQLite mode implementation.

## Issues Identified and Resolved

### 1. Docker vs Containerd Architecture Conflict
**Problem**: The playbook installs Docker while RKE2 uses its own embedded containerd runtime, creating unnecessary dependencies and confusion.

**Resolution**:
- Updated comments in `playbook.yml` to clarify Docker is optional (for GPU toolkit and manual operations)
- Removed Docker service dependencies from systemd templates
- Fixed incorrect comments suggesting RKE2 uses Docker as runtime
- Made systemd service creation conditional to avoid conflicts in SQLite mode

### 2. Systemd Service Template Conflicts
**Problem**: LXC-specific systemd templates (`rke2-server-lxc.service.j2`, `rke2-agent-lxc.service.j2`) incorrectly specified Docker service dependencies.

**Resolution**:
- Removed `After=docker.service` dependencies from LXC service templates
- Added comments clarifying RKE2 uses built-in containerd, not Docker
- Made LXC service installation conditional (only when NOT using SQLite mode)

### 3. SQLite Mode Compatibility
**Problem**: LXC fixes were replacing systemd services that conflicted with SQLite mode's systemd overrides approach.

**Resolution**:
- Added conditional logic: `when: not rke2_use_sqlite | bool`
- SQLite mode uses systemd overrides instead of complete service replacement
- Both approaches can coexist without conflicts

### 4. Missing Systemd Daemon Reload
**Problem**: SQLite mode systemd overrides were created without proper daemon reload.

**Resolution**:
- Added `daemon_reload: true` to SQLite mode tasks after creating override files
- Ensures systemd recognizes new configuration before service operations

## Current Deployment Flow

1. **LXC Fixes** (`lxc_fixes.yml`) - Runs for all deployments
   - Kernel parameter fixes
   - `/dev/kmsg` workarounds  
   - LXC-specific systemd services (only if NOT SQLite mode)
   - Network and container runtime optimizations

2. **SQLite Mode** (`sqlite_mode.yml`) - Runs only when `rke2_use_sqlite=true`
   - SQLite database initialization
   - Systemd service overrides (instead of replacements)
   - SQLite-specific configuration

## Key Changes Made

### In `lxc_fixes.yml`:
- Made systemd service creation conditional: `when: not rke2_use_sqlite | bool`
- Removed Docker dependencies from service templates
- Added informational messages when SQLite mode is detected

### In `sqlite_mode.yml`:
- Added proper `daemon_reload: true` after creating systemd overrides
- Ensured compatibility with LXC fixes

### In Templates:
- `rke2-server-lxc.service.j2`: Removed `After=docker.service`
- `rke2-agent-lxc.service.j2`: Removed `After=docker.service`  
- `config.yaml.j2`: Fixed incorrect Docker runtime comments

### In `playbook.yml`:
- Added clarification that Docker installation is optional
- Documented that RKE2 uses embedded containerd, not Docker

## Validation

The conflicts have been resolved through:
1. **Conditional Logic**: LXC service replacement vs SQLite overrides
2. **Dependency Cleanup**: Removed unnecessary Docker dependencies
3. **Proper Sequencing**: Ensured systemd daemon reloads happen at correct times
4. **Clear Documentation**: Comments explain architecture choices

## Result

Both LXC fixes and SQLite mode can now coexist without conflicts:
- Standard LXC deployments get full service replacements
- SQLite LXC deployments get systemd overrides + LXC kernel/network fixes
- No Docker dependencies interfere with RKE2's embedded containerd
- Proper systemd management ensures services start correctly

## Testing Recommendation

Test both deployment scenarios:
1. Standard LXC deployment (without SQLite)
2. LXC + SQLite deployment

Verify that:
- Services start correctly in both modes
- No Docker-related errors occur
- SQLite database is properly initialized
- LXC-specific fixes are applied in both scenarios
