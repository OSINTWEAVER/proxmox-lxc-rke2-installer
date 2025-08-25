# RKE2 Cluster Access Information

## Quick Start - Using Aliases

SSH to any cluster node and use the preconfigured aliases:
```bash
# View cluster nodes
kubectl get nodes

# List helm releases
helm list --all-namespaces

# Interactive cluster management
k9s
```

## Tool Locations

All tools are installed system-wide:
- kubectl: `/usr/local/bin/kubectl`
- helm: `/usr/local/bin/helm`
- k9s: `/usr/local/bin/k9s`

## Manual KUBECONFIG Setup

If aliases don't work, export the kubeconfig:
```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
helm list --all-namespaces
k9s
```

## User Access (adm4n)

The adm4n user has kubectl access via:
- Personal kubeconfig: `~/.kube/config`
- Aliases in `~/.bashrc` for kubectl, helm, k9s, k (kubectl shortcut)

## Cluster Architecture

### Core Components
- **Kubernetes Version**: 1.32.7 (via RKE2 v1.32.7+rke2r1)
- **CNI**: Flannel (optimized for LXC containers)
- **Runtime**: RKE2 Embedded Containerd (Docker-free)
- **Datastore**: SQLite (single server + multi-agent architecture)

### Storage
- **Local Path Provisioner**: Available at /mnt/data
- **ZFS Volumes**: Mounted at `/mnt/data` on all nodes

### GPU Support
- **NVIDIA Container Toolkit**: Directly configured in containerd for LXC compatibility
- **NVIDIA Runtime**: Available for GPU workloads without operator complexity

## Management Commands

```bash
# Cluster status
kubectl get nodes,pods --all-namespaces

# Install applications with Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-app bitnami/nginx

# Interactive debugging and monitoring
k9s
```

## Troubleshooting

```bash
# Service logs
journalctl -u rke2-server    # Control plane
journalctl -u rke2-agent     # Worker nodes

# Pod logs and debugging
kubectl logs -n kube-system <pod-name>
kubectl describe pod <pod-name>

# Network debugging
kubectl get pods -o wide
kubectl get svc --all-namespaces
```

## Deployment Status

- ✅ **RKE2 Cluster**: Operational (SQLite datastore)
- ✅ **Flannel CNI**: Active on all nodes
- ✅ **kubectl**: Installed and configured
- ✅ **helm**: Installed and configured
- ✅ **k9s**: Installed and configured
- ✅ **Local Path Provisioner**: Ready for storage
- ✅ **NVIDIA Container Toolkit**: Handled by RKE2 role for GPU workloads
- ✅ **Rancher UI**: Available at https://rancher.example.com
