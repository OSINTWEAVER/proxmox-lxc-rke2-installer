# 🚨 CRITICAL DNS AND NETWORKING FIXES

## Root Cause Analysis
Based on the stern log showing helm-operation pods stuck in a loop with:
- `dial tcp: lookup kubernetes.default: i/o timeout`
- `Error while proxying request`

## Issues Identified:

### 1. **DNS Resolution Failure**
- `kubernetes.default` service cannot be resolved
- CoreDNS may not be properly configured or running
- kubelet DNS settings may be incorrect

### 2. **Potential Service CIDR Mismatch**
- kubelet points to DNS at `10.43.0.10` (hardcoded)
- But actual CoreDNS service may be on different IP
- Service CIDR configuration mismatch

### 3. **CNI/Network Policy Issues**
- Flannel may not be properly configured
- Network policies blocking internal communication
- Bridge networking issues in LXC

## Immediate Fixes Required:

### Fix 1: Add missing DNS configuration to defaults/main.yml
```yaml
# DNS Configuration for RKE2 (add to defaults/main.yml)
rke2_cluster_dns: "10.43.0.10"
rke2_cluster_domain: "cluster.local"
rke2_service_cidr: ["10.43.0.0/16"]
rke2_cluster_cidr: ["10.42.0.0/16"]
```

### Fix 2: Verify CoreDNS is in correct namespace and IP
- Check if CoreDNS is running in kube-system namespace
- Verify service IP matches kubelet configuration
- Ensure service CIDR allocation is correct

### Fix 3: Add DNS troubleshooting to lxc_fixes.yml
- Add CoreDNS health checks
- Add service discovery verification
- Add network connectivity tests

### Fix 4: Update containerd configuration for LXC
- Ensure containerd can reach external DNS
- Configure proper DNS for container runtime
- Add DNS fallback mechanisms

## Testing Commands:
```bash
# Check CoreDNS status
kubectl get svc -n kube-system | grep dns
kubectl get pods -n kube-system | grep coredns

# Test DNS resolution inside cluster
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Check service CIDR
kubectl cluster-info dump | grep service-cluster-ip-range
```
