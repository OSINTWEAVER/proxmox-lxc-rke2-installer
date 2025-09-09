# SSL Webapp Health Check Tool

Modern dark-themed SSL health check webapp for RKE2 clusters with Let's Encrypt certificates.

## Files

- `certificate.yaml` - Let's Encrypt SSL certificate template
- `configmap.yaml` - HTML content template  
- `deployment.yaml` - Kubernetes deployment template
- `service.yaml` - Kubernetes service template
- `ingress.yaml` - Nginx ingress template with SSL
- `rbac.yaml` - ServiceAccount and RBAC permissions for cluster access
- `nginx-config.yaml` - Nginx configuration for API proxying
- `deploy.sh` - Main deployment script
- `cleanup.sh` - Cleanup script

## Usage

**Note:** See `test.md` for actual test commands with real domain names.

### Deploy a health check webapp:
```bash
./deploy.sh test.example.com "System Health Check - All Services Operational"
```

### Clean up:
```bash
./cleanup.sh test.example.com
```

## Features

- ✅ Automatic Let's Encrypt SSL certificate creation (HTTP-01 validation)
- ✅ Individual certificates per subdomain (no wildcards needed)
- ✅ Modern dark theme with black, grey, and orange styling
- ✅ **Real-time cluster statistics** - Live CPU, memory, node, and GPU metrics
- ✅ **GPU Detection** - Automatically detects NVIDIA GPUs and types
- ✅ **Node Classification** - Distinguishes control plane vs worker nodes
- ✅ SSL status monitoring and pod health checks
- ✅ Template-based YAML files (clean and maintainable)
- ✅ Simple variable substitution
- ✅ Automatic cleanup of existing resources
- ✅ Resource limits and proper labels
- ✅ Force SSL redirect
- ✅ Professional responsive design
- ✅ Auto-refreshing stats every 30 seconds
- ✅ Kubernetes RBAC security model

## Requirements

- RKE2 cluster with cert-manager
- Nginx ingress controller
- Let's Encrypt ClusterIssuer named "letsencrypt-prod"
- Proper DNS records pointing to your cluster

## Real Cluster Statistics

The webapp includes a **real-time cluster monitoring service** that gathers live statistics from the Kubernetes API:

- **Sidecar Container**: Alpine-based service with Kubernetes API client
- **API Endpoint**: `/api/cluster-stats` provides JSON cluster metrics
- **Frontend Integration**: JavaScript fetches real cluster data every 30 seconds
- **RBAC Security**: Minimal permissions (read-only access to nodes)
- **Live Metrics**: All data is gathered in real-time from the cluster

### Displayed Statistics:
- 🖥️ **Worker Nodes** - Count of worker nodes in the cluster
- ⚙️ **Control Nodes** - Count of control plane nodes
- 🔢 **Total CPUs** - Sum of all CPU cores across all nodes
- 💾 **Total Memory** - Sum of all memory across all nodes (in GB)
- 🎮 **GPU Devices** - Count of NVIDIA GPUs detected
- 🏷️ **GPU Types** - List of GPU models found in the cluster

### Color Coding:
- ✅ **Green** - Statistics successfully loaded
- 🟠 **Orange** - No GPUs detected (normal for CPU-only clusters)
- ❌ **Red** - Error fetching cluster data

## Template Variables

The following variables are substituted in the YAML templates:

- `{{SUBDOMAIN}}` - Full subdomain (e.g., test.example.com)
- `{{DOMAIN}}` - Base domain (e.g., example.com)  
- `{{SANITIZED_DOMAIN}}` - Domain with dots as hyphens (e.g., example-com)
- `{{SANITIZED_SUBDOMAIN}}` - Subdomain with dots as hyphens (e.g., test-example-com)
- `{{MESSAGE}}` - Custom message for the webpage
- `{{TIMESTAMP}}` - Deployment timestamp
