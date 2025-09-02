# Webapp Deployment Smoke Test

This test validates that your RKE2 cluster can successfully deploy, schedule, and expose a web application.

## What This Test Does

✅ **Cluster Connectivity** - Verifies kubectl can communicate with the cluster  
✅ **Pod Scheduling** - Deploys 2 replicas across available nodes  
✅ **Service Networking** - Creates NodePort service for external access  
✅ **Container Runtime** - Tests container pulling and execution  
✅ **DNS Resolution** - Validates internal cluster DNS  
✅ **Load Balancing** - Tests service load balancing between pods  

## Test Components

- **`test-webapp.yaml`** - Kubernetes manifests for:
  - ConfigMap with HTML content
  - Deployment with 2 replicas
  - NodePort Service (port 30080)
  - Ingress configuration
- **`deploy-test-webapp.sh`** - Deployment script with status checks

## Prerequisites

- RKE2 cluster is deployed and running
- kubectl access to the cluster
- SSH access to a control plane node

## How to Run

### Method 1: Remote Deployment (Recommended)

From your Windows machine, copy files to control plane and deploy:

```powershell
# Copy files to control plane
scp test-webapp.yaml adm4n@10.14.100.1:/tmp/
scp deploy-test-webapp.sh adm4n@10.14.100.1:/tmp/

# SSH to control plane and deploy
ssh adm4n@10.14.100.1
cd /tmp
chmod +x deploy-test-webapp.sh
sudo ./deploy-test-webapp.sh
```

### Method 2: Direct kubectl (if you have local kubectl configured)

```bash
kubectl apply -f test-webapp.yaml
kubectl wait --for=condition=available --timeout=300s deployment/funny-webapp
kubectl get pods,svc -l app=funny-webapp
```

## Access the Test Webapp

Once deployed, access the webapp at:

- **Direct NodePort**: `http://[any-node-ip]:30080`
  - http://10.14.100.1:30080
  - http://10.14.100.2:30080  
  - http://10.14.100.3:30080

## What You Should See

A fun, interactive webpage that shows:

- 🚀 Cluster information and node details
- 🎨 Click anywhere to change background colors
- 🎮 Konami Code easter egg (↑↑↓↓←→←→BA)
- 📱 Responsive design that works on mobile
- 🔄 Real-time cluster information

## Troubleshooting

### Pods Not Starting
```bash
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get pods -l app=funny-webapp
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl describe pods -l app=funny-webapp
```

### Service Not Accessible
```bash
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get svc funny-webapp-service
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl describe svc funny-webapp-service
```

### Port Forward Alternative
If NodePort isn't working, try port forwarding:
```bash
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl port-forward svc/funny-webapp-service 8080:80
# Then access: http://localhost:8080
```

## Cleanup

To remove the test webapp:

```bash
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl delete -f /tmp/test-webapp.yaml
```

## Expected Results

- ✅ **PASS**: Webapp loads and shows cluster info
- ✅ **PASS**: Multiple pods running across nodes
- ✅ **PASS**: Service accessible via NodePort
- ✅ **PASS**: Interactive features work (color changes, etc.)

## Validation Checklist

- [ ] Pods deploy successfully (2/2 ready)
- [ ] Service has valid ClusterIP and NodePort
- [ ] Webpage loads and displays cluster information
- [ ] Can access from multiple node IPs
- [ ] Interactive features work (click to change colors)
- [ ] No error messages in pod logs

This test confirms your RKE2 cluster is fully functional for production workloads! 🎉
