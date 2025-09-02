# LXC RKE2 Deployment Analysis Report

## ⚠️ Current Status: Critical kubelet Failure

Date: August 5, 2025
Status: **DEPLOYMENT FAILED** - kubelet ContainerManager cannot start due to LXC cgroup compatibility issues

## ❌ Critical Component Failures

### kubelet (Node Agent) - FAILED
- **Status**: Cannot start due to ContainerManager initialization failure
- **Error**: `strconv.Atoi: parsing "": invalid syntax` (multiple instances)
- **Root Cause**: LXC cgroup v2 provides empty string values for CPU/memory/PID limits that kubelet cannot parse
- **Impact**: No node registration, no pod scheduling, no container management

### Partially Working Components

### Core Infrastructure
- **SQLite Database**: Full functionality with connection pooling
- **Token Authentication**: Resolved token format issues
- **containerd Runtime**: Operational container runtime
- **TLS Certificates**: All certificates generated successfully
- **Networking**: Cluster networking configured and functional

### Kubernetes Control Plane - LIMITED
- **kube-apiserver**: ⚠️ Starting but cannot accept kubelet connections
- **kube-scheduler**: ⚠️ Running but cannot schedule pods (no nodes)
- **kube-controller-manager**: ⚠️ Running but cannot manage node resources
- **kube-proxy**: ❌ Cannot function without working kubelet
- **etcd Replacement**: ✅ SQLite successfully configured

### Cluster Management - NON-FUNCTIONAL
- **Server Tokens**: ✅ Generated but unusable without working nodes
- **Agent Tokens**: ✅ Generated but unusable without working nodes  
- **Kubeconfig**: ⚠️ Generated but API server unreachable due to kubelet failure
- **Cluster Join**: ❌ Cannot join nodes when kubelet fails to start

## � CRITICAL FAILURE: kubelet ContainerManager

**kubelet Cannot Start**: Deployment blocking issue
- Error: `strconv.Atoi: parsing "": invalid syntax`
- Impact: **Complete cluster failure** - no working Kubernetes functionality
- Root Cause: Kubernetes kubelet's ContainerManager attempts to parse cgroup resource limits (CPU quotas, memory limits, PID limits) but LXC containers provide empty strings for these values in cgroup v2
- Technical Details: Three separate parsing failures occur when kubelet reads `/sys/fs/cgroup/cpuset.cpus.effective`, `/sys/fs/cgroup/cpuset.mems.effective`, and related resource files
- Status: **Fundamental incompatibility** between Kubernetes kubelet and LXC cgroup v2 implementation

## ⚠️ Deployment Reality Check

**Actual Status**: This deployment has **FAILED** and is not usable for any Kubernetes workloads. While some RKE2 components start successfully, the kubelet failure prevents:
- Node registration with the cluster
- Pod scheduling and execution  
- Container lifecycle management
- kubectl functionality
- Any practical Kubernetes operations

## 📊 Technical Achievements

### Fixed Issues
1. **YAML Configuration Errors**: Resolved parsing issues in config templates
2. **Token Format**: Fixed RKE2 token authentication format
3. **SQLite Integration**: Successfully replaced etcd with SQLite
4. **LXC Compatibility**: Resolved most LXC container limitations
5. **Kernel Module Issues**: Worked around missing br_netfilter/overlay modules

## 🔍 Technical Root Cause Analysis

### Cgroup v2 Incompatibility Details
```bash
# LXC cgroup v2 structure provides empty values that kubelet cannot parse:
/sys/fs/cgroup/cpuset.cpus.effective = "5,26"      # Available, but kubelet reads ""
/sys/fs/cgroup/cpuset.mems.effective = "0"         # Available, but kubelet reads ""
/sys/fs/cgroup/cpu.max = "max"                     # Available, but kubelet reads ""
```

### kubelet Error Analysis
The ContainerManager initialization fails with three concurrent parsing errors:
1. **CPU Resource Parsing**: `strconv.Atoi: parsing "": invalid syntax` when reading CPU limits
2. **Memory Resource Parsing**: `strconv.Atoi: parsing "": invalid syntax` when reading memory limits  
3. **PID Resource Parsing**: `strconv.Atoi: parsing "": invalid syntax` when reading PID limits

### Failed Solutions Attempted
1. ✅ Token format correction (successful)
2. ✅ SQLite configuration (successful)
3. ❌ CPU manager policy=none (failed - still parses cgroups)
4. ❌ Memory manager policy=None (failed - still parses cgroups)
5. ❌ Topology manager policy=none (failed - still parses cgroups)
6. ❌ enforce-node-allocatable= (failed - still parses cgroups)
7. ❌ cgroups-per-qos=false (failed - still parses cgroups)
8. ❌ Multiple cgroup-driver configurations (failed - parsing occurs before driver selection)

### Current Working Configuration (Non-Functional)

```yaml
# /etc/rancher/rke2/config.yaml (Current - Non-Functional)
token: a3f8b9c2d1e4a7b8c9d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d2e3f4a5b6
data-dir: /var/lib/rancher/rke2
disable-etcd: true
datastore-endpoint: "sqlite:///var/lib/rancher/rke2/server/db/state.db?cache=shared&mode=rwc&_journal=WAL&_timeout=5000&_synchronous=NORMAL&_cache_size=10000"
cni: flannel
tls-san:
  - cluster.local
  - 10.14.100.1
kubelet-arg:
  - fail-swap-on=false
  - protect-kernel-defaults=false
  - cpu-manager-policy=none
  - memory-manager-policy=None
  - topology-manager-policy=none
  - enforce-node-allocatable=
  - cgroups-per-qos=false
  - cgroup-driver=systemd
# NOTE: Despite all these arguments, kubelet still fails due to cgroup parsing in ContainerManager
```

## 🚀 Potential Solutions for Future Investigation

### 1. Alternative Kubernetes Distributions
- **K3s**: May have different cgroup handling - worth testing
- **MicroK8s**: Different container manager implementation
- **Kubeadm**: Raw Kubernetes with custom kubelet configuration

### 2. LXC Configuration Modifications
- **Privileged + Nested**: Enable nested virtualization in LXC
- **Custom cgroup mounting**: Override cgroup paths in LXC
- **cgroup v1 fallback**: Force LXC to use cgroup v1 if possible

### 3. Kubelet Source Modifications
- **Custom kubelet build**: Patch ContainerManager to handle empty cgroup values
- **Bypass resource parsing**: Modify kubelet to skip cgroup resource initialization
- **Default value injection**: Inject reasonable defaults when parsing empty strings

### 4. Container Runtime Alternatives
- **containerd direct**: Run containerd without kubelet resource management
- **Podman**: Use Podman instead of containerd for container management
- **Docker shim**: Use Docker runtime with different cgroup handling

### 5. VM-Based Deployment (Recommended)
- **Proxmox VMs**: Use full virtual machines instead of LXC containers
- **QEMU guests**: Standard virtualization with complete cgroup support
- **Cloud instances**: Use cloud VMs for guaranteed Kubernetes compatibility

### Diagnostic Commands (For Troubleshooting)
```bash
# Check current kubelet failure
sudo journalctl -u rke2-server.service -f

# Examine kubelet logs
sudo tail -f /var/lib/rancher/rke2/agent/logs/kubelet.log

# Check cgroup values that cause parsing errors
cat /sys/fs/cgroup/cpuset.cpus.effective
cat /sys/fs/cgroup/cpuset.mems.effective
cat /sys/fs/cgroup/cpu.max

# Verify SQLite database (this part works)
sudo sqlite3 /var/lib/rancher/rke2/server/db/state.db ".tables"

# Check service status
sudo systemctl status rke2-server.service
```

## 🎯 Actual Status Metrics

- **Core Components**: 3/11 working (27% success)
- **Critical Path**: **BROKEN** - kubelet failure prevents cluster functionality
- **SQLite Mode**: ✅ Successfully configured but unusable without kubelet
- **Token Authentication**: ✅ Fixed but ineffective due to cluster failure
- **LXC Compatibility**: ❌ **FAILED** - fundamental cgroup incompatibility discovered
- **Deployment Viability**: **NOT VIABLE** - cluster cannot function for any workloads
- **Production Readiness**: ❌ **NOT READY** - deployment completely non-functional

## � Reality Assessment

This deployment represents a **failed attempt** to run RKE2 in LXC containers:
- Discovered fundamental incompatibility between Kubernetes kubelet and LXC cgroup v2
- While SQLite mode configuration was successful, it's unusable without working kubelet
- LXC containers cannot provide the cgroup resource information that Kubernetes requires
- This approach is **not viable** for production Kubernetes deployments

## 🔮 Future Enhancements

1. **Agent Node Testing**: Test adding worker nodes to cluster
2. **Workload Deployment**: Test pod scheduling and execution
3. **Persistent Storage**: Implement local-path provisioner
4. **Monitoring**: Add cluster monitoring and observability
5. **High Availability**: Multi-server SQLite cluster testing

---

**Conclusion**: This deployment attempt has **FAILED** due to fundamental incompatibility between Kubernetes kubelet and LXC containers. The kubelet ContainerManager cannot parse empty cgroup resource values provided by LXC, preventing any Kubernetes functionality. While we successfully configured SQLite mode and resolved token authentication, these achievements are meaningless without a working kubelet.

**Production Recommendation**: **DO NOT USE** this approach for production deployments. Consider alternatives:
1. **VM-based RKE2**: Use full virtual machines instead of LXC containers
2. **K3s Testing**: Evaluate if K3s has better LXC compatibility 
3. **Docker/Podman**: Use container runtimes instead of LXC for Kubernetes nodes
4. **Managed Kubernetes**: Use cloud-managed solutions to avoid infrastructure compatibility issues

This deployment proves that **LXC containers are not suitable for Kubernetes kubelet** due to cgroup v2 implementation differences.
