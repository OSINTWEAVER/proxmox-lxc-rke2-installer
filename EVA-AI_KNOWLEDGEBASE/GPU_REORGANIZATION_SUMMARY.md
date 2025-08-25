# GPU Support Reorganization - CRITICAL UPDATE

## What Changed
**GPU tasks have been moved to run LAST and made completely optional!** This resolves the hanging issue during deployment.

## Problem Solved
- **Issue**: NVIDIA Container Toolkit installation was hanging during deployment
- **Cause**: GPU tasks were running too early in the deployment process
- **Solution**: Moved GPU tasks to run after RKE2 cluster is fully functional

## New GPU Task Flow
1. **Before**: GPU tasks ran during `lxc_fixes.yml` (early in deployment)
2. **After**: GPU tasks run in separate `gpu.yml` file AFTER cluster is working

## Files Modified
- ✅ **Created**: `ansible-role-rke2/tasks/gpu.yml` - All GPU tasks moved here
- ✅ **Modified**: `ansible-role-rke2/tasks/lxc_fixes.yml` - GPU tasks removed
- ✅ **Modified**: `ansible-role-rke2/tasks/main.yml` - GPU tasks run LAST
- ✅ **Modified**: `ansible-role-rke2/defaults/main.yml` - GPU configuration variables
- ✅ **Created**: `deploy-no-gpu.sh` - Quick deployment without GPU support

## GPU Configuration Variables
```yaml
# In hosts.ini or group_vars:
rke2_enable_gpu_support: false  # Enable GPU support (default: false)
is_gpu_node: false             # Mark specific nodes as GPU nodes
gpu_node_pattern: "gpu|nvidia" # Pattern to auto-detect GPU nodes
```

## Deployment Options

### Option 1: Deploy WITHOUT GPU Support (Recommended First)
```bash
./deploy-no-gpu.sh
```
This will get your cluster working without any GPU complications.

### Option 2: Deploy WITH GPU Support
```bash
# Add to hosts.ini:
rke2_enable_gpu_support=true

# Then run normal deployment:
./deploy.sh hosts.ini
```

### Option 3: Add GPU Support Later
1. Deploy cluster without GPU first
2. Set `rke2_enable_gpu_support=true` in hosts.ini
3. Re-run deployment to add GPU support

## GPU Task Features
- ✅ **Non-blocking**: GPU failure won't break cluster deployment
- ✅ **Optional**: Only runs when explicitly requested
- ✅ **Timeout protection**: 10-minute timeout prevents hanging
- ✅ **Better error handling**: Failed GPU setup doesn't fail deployment
- ✅ **Detailed logging**: Shows exactly what's happening

## Migration Guide
If you have an existing deployment that's hanging:

1. **Stop current deployment**: Ctrl+C the hanging deployment
2. **Clean failed state**: 
   ```bash
   ansible -i inventories/hosts.ini all -m shell -a "pkill -f rke2 || true"
   ```
3. **Deploy without GPU first**:
   ```bash
   ./deploy-no-gpu.sh
   ```
4. **Add GPU support later** (optional):
   ```bash
   # Set rke2_enable_gpu_support=true in hosts.ini
   ./deploy.sh hosts.ini
   ```

## Benefits
- 🚀 **Faster deployment**: Core cluster deploys without GPU delays
- 🔧 **Better debugging**: GPU issues don't mask cluster issues
- 💪 **More reliable**: Core Kubernetes works regardless of GPU status
- 🎯 **Focused troubleshooting**: Separate GPU and cluster concerns
- ⚡ **No hanging**: Timeouts and better error handling prevent freezes
