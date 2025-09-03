#!/bin/bash
# RKE2 Networking Diagnostics for LXC Containers
# Run this on your cluster nodes to diagnose DNS/networking issues

echo "========================================"
echo "🔍 RKE2 NETWORKING DIAGNOSTIC REPORT"
echo "========================================"
echo "Timestamp: $(date)"
echo "Node: $(hostname)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. CLUSTER SERVICE STATUS${NC}"
echo "----------------------------------------"
sudo systemctl status rke2-server.service --no-pager --lines=5 2>/dev/null || \
sudo systemctl status rke2-agent.service --no-pager --lines=5 2>/dev/null
echo ""

echo -e "${BLUE}2. CONTAINER RUNTIME STATUS${NC}"
echo "----------------------------------------"
if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo -e "${GREEN}✓ Containerd socket available${NC}"
    sudo /var/lib/rancher/rke2/bin/ctr --address /run/k3s/containerd/containerd.sock version 2>/dev/null | head -3
else
    echo -e "${RED}✗ Containerd socket not found${NC}"
fi
echo ""

echo -e "${BLUE}3. KUBERNETES CLUSTER STATUS${NC}"
echo "----------------------------------------"
if [ -f /etc/rancher/rke2/rke2.yaml ]; then
    echo -e "${GREEN}✓ Kubeconfig exists${NC}"
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    kubectl version --client --short 2>/dev/null
    echo ""
    echo "Cluster nodes:"
    kubectl get nodes -o wide 2>/dev/null | head -5
    echo ""
    echo "System pods status:"
    kubectl get pods -n kube-system | grep -E "(coredns|flannel)" | head -5
else
    echo -e "${RED}✗ Kubeconfig not found${NC}"
fi
echo ""

echo -e "${BLUE}4. DNS CONFIGURATION CHECK${NC}"
echo "----------------------------------------"
echo "DNS configuration in kubelet-config:"
if [ -f /etc/rancher/rke2/kubelet-config.yaml ]; then
    grep -A2 "clusterDNS" /etc/rancher/rke2/kubelet-config.yaml 2>/dev/null
else
    echo -e "${YELLOW}⚠ kubelet-config.yaml not found${NC}"
fi
echo ""

echo "CoreDNS Service:"
kubectl get svc -n kube-system kube-dns 2>/dev/null || \
kubectl get svc -n kube-system rke2-coredns-rke2-coredns 2>/dev/null || \
echo -e "${RED}✗ CoreDNS service not found${NC}"
echo ""

echo -e "${BLUE}5. SERVICE DISCOVERY TEST${NC}"
echo "----------------------------------------"
echo "Testing kubernetes.default service resolution:"
kubectl run dns-test --image=busybox --rm -it --restart=Never --timeout=30s -- nslookup kubernetes.default 2>/dev/null || \
echo -e "${RED}✗ DNS resolution test failed${NC}"
echo ""

echo -e "${BLUE}6. NETWORK CONNECTIVITY${NC}"
echo "----------------------------------------"
echo "Flannel pods:"
kubectl get pods -n kube-system -l app=flannel 2>/dev/null | head -5
echo ""
echo "CNI configuration:"
ls -la /etc/cni/net.d/ 2>/dev/null | head -5
echo ""

echo -e "${BLUE}7. HELM OPERATIONS STATUS${NC}"
echo "----------------------------------------"
echo "Recent helm operations (showing errors):"
kubectl get pods -n cattle-system -l job-name --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -10
echo ""
echo "Failing helm operation logs (last 5 lines):"
FAILING_POD=$(kubectl get pods -n cattle-system -l job-name --field-selector=status.phase=Failed -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$FAILING_POD" ]; then
    kubectl logs $FAILING_POD -n cattle-system --tail=5 2>/dev/null
else
    echo "No failed helm operations found"
fi
echo ""

echo -e "${BLUE}8. LXC CONTAINER DIAGNOSTICS${NC}"
echo "----------------------------------------"
echo "Container features:"
if [ -f /proc/1/environ ]; then
    echo "Running in container: $(grep -q container=lxc /proc/1/environ && echo 'LXC' || echo 'Unknown')"
fi
echo "Available kernel modules:"
lsmod | grep -E "(br_netfilter|overlay|ip_tables)" | head -5
echo ""

echo -e "${BLUE}9. RECOMMENDED FIXES${NC}"
echo "----------------------------------------"
if [ -S /run/k3s/containerd/containerd.sock ]; then
    echo -e "${GREEN}✓ Container runtime OK${NC}"
else
    echo -e "${RED}1. Restart RKE2 service${NC}"
fi

kubectl get svc -n kube-system kube-dns >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ DNS service OK${NC}"
else
    echo -e "${RED}2. Check CoreDNS deployment${NC}"
fi

echo ""
echo "========================================"
echo "🔍 DIAGNOSTIC COMPLETE"
echo "========================================"
