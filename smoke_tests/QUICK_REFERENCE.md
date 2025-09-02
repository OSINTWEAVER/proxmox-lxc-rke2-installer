# Quick Test Commands

## Webapp Deployment Test
```bash
# Copy and deploy
scp smoke_tests/webapp_deployment_test/* adm4n@10.14.100.1:/tmp/
ssh adm4n@10.14.100.1 "cd /tmp && chmod +x deploy-test-webapp.sh && sudo ./deploy-test-webapp.sh"

# Access
http://10.14.100.1:30080

# Cleanup
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl delete -f /tmp/test-webapp.yaml"
```

## Disk Performance Test (FIO Benchmarks)
```bash
# Copy and deploy
scp smoke_tests/disk_performance_test/* adm4n@10.14.100.1:/tmp/
ssh adm4n@10.14.100.1 "cd /tmp && chmod +x deploy-fio-benchmark.sh && sudo ./deploy-fio-benchmark.sh"

# Access Dashboard
http://10.14.100.1:30081

# Run manual benchmarks
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl exec -it <fio-pod-name> -- /tmp/run-benchmarks.sh"

# Cleanup
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl delete -f /tmp/fio-benchmark-test.yaml"
```

## Status Checks
```bash
# Check nodes
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get nodes"

# Check all pods
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get pods --all-namespaces"

# Check test webapp specifically  
ssh adm4n@10.14.100.1 "sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get pods,svc -l app=funny-webapp"
```
