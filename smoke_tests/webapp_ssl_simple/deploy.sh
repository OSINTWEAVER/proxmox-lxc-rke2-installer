#!/bin/bash
# Simple SSL Webapp Deployment Script
# Uses template YAML files with variable substitution

set -e

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <subdomain.domain.com> \"<custom message>\""
    echo "Example: $0 test.example.com \"Hello from my test site!\""
    exit 1
fi

SUBDOMAIN="$1"
MESSAGE="$2"

# Extract domain from subdomain
DOMAIN=$(echo "$SUBDOMAIN" | cut -d'.' -f2-)

# Sanitize names for Kubernetes (replace dots with hyphens)
SANITIZED_DOMAIN=$(echo "$DOMAIN" | sed 's/\./-/g')
SANITIZED_SUBDOMAIN=$(echo "$SUBDOMAIN" | sed 's/\./-/g')

echo "🚀 Deploying SSL Test Webapp"
echo "=============================="
echo "Subdomain: $SUBDOMAIN"
echo "Domain: $DOMAIN"
echo "Message: $MESSAGE"
echo ""

# Set kubeconfig
if [ -f ~/.kube/config ]; then
    export KUBECONFIG=~/.kube/config
elif [ -f /etc/rancher/rke2/rke2.yaml ]; then
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
else
    echo "❌ No kubeconfig found!"
    echo "   Run: ./scripts/fetch_kubeconfig.bat inventories/hosts-iris.ini"
    exit 1
fi

# Check cluster connection
echo "📋 Checking cluster connection..."
kubectl get nodes -o wide || { echo "❌ Cannot connect to cluster"; exit 1; }

echo ""
echo "🔍 Detecting GPU availability..."

# Check if any nodes have nvidia.com/gpu.present=true label
GPU_NODES=$(kubectl get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)

if [ "$GPU_NODES" -gt 0 ]; then
    echo "   ✅ Found $GPU_NODES GPU-enabled nodes - will use NVIDIA runtime"
    USE_NVIDIA_RUNTIME=true
    CONTAINER_IMAGE="nvidia/cuda:13.0.0-base-ubuntu24.04"
    RUNTIME_CLASS_LINE="runtimeClassName: nvidia"
else
    echo "   ℹ️  No GPU nodes detected - using standard runtime"
    USE_NVIDIA_RUNTIME=false
    CONTAINER_IMAGE="ubuntu:24.04"
    RUNTIME_CLASS_LINE=""
fi

echo ""
echo "🧹 Cleaning up existing resources..."

# Clean up existing resources
kubectl delete configmap ssl-test-html-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete configmap ssl-test-nginx-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete deployment ssl-test-webapp-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete service ssl-test-webapp-service-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete serviceaccount ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete clusterrole ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete clusterrolebinding ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete pvc ssl-test-cluster-stats-$SANITIZED_SUBDOMAIN --ignore-not-found=true

# Wait for cleanup
echo "   Waiting for cleanup to complete..."
sleep 3

echo ""
echo "🔒 Creating SSL certificate..."

# Create certificate for this specific subdomain
echo "   📜 Creating certificate for subdomain: $SUBDOMAIN"
# Apply certificate template
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    certificate.yaml | kubectl apply -f -

echo ""
echo "🌐 Deploying webapp resources..."

# Deploy PVC first
echo "   💾 Creating Persistent Volume Claim for cluster stats..."
sed -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    pvc.yaml | kubectl apply -f -

# Deploy RBAC
echo "   🔐 Creating RBAC permissions..."
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    rbac.yaml | kubectl apply -f -

# Deploy ConfigMap
echo "   📄 Creating HTML ConfigMap..."
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    -e "s/{{MESSAGE}}/$MESSAGE/g" \
    configmap.yaml | kubectl apply -f -

# Deploy Nginx Config
echo "   ⚙️  Creating Nginx ConfigMap..."
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    nginx-config.yaml | kubectl apply -f -

# Deploy Deployment
echo "   🚀 Creating Deployment..."

# Create deployment YAML with conditional runtime class
if [ "$USE_NVIDIA_RUNTIME" = true ]; then
    RUNTIME_CLASS_SPEC="      runtimeClassName: nvidia\n"
else
    RUNTIME_CLASS_SPEC=""
fi

sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    -e "s|{{CONTAINER_IMAGE}}|$CONTAINER_IMAGE|g" \
    -e "s|{{RUNTIME_CLASS_SPEC}}|$RUNTIME_CLASS_SPEC|g" \
    deployment.yaml | kubectl apply -f -

# Deploy Service
echo "   🌐 Creating Service..."
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    service.yaml | kubectl apply -f -

# Deploy Ingress
echo "   🔗 Creating Ingress..."
sed -e "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" \
    -e "s/{{SANITIZED_SUBDOMAIN}}/$SANITIZED_SUBDOMAIN/g" \
    ingress.yaml | kubectl apply -f -

echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/ssl-test-webapp-$SANITIZED_SUBDOMAIN

echo ""
echo "🔍 Checking certificate status..."
kubectl get certificate $SANITIZED_SUBDOMAIN-cert -n default || echo "   Certificate not found"

echo ""
echo "📊 Deployment Status:"
kubectl get pods,svc,ingress -l app=ssl-test-webapp,subdomain=$SUBDOMAIN

echo ""
echo "✅ Deployment Complete!"
echo "========================"
echo "🌐 Access your SSL webapp at: https://$SUBDOMAIN"
echo ""
echo "🛠️  Troubleshooting Commands:"
echo "   kubectl get pods -l subdomain=$SUBDOMAIN"
echo "   kubectl logs -l subdomain=$SUBDOMAIN"
echo "   kubectl describe certificate $SANITIZED_SUBDOMAIN-cert"
echo "   kubectl get secret $SANITIZED_SUBDOMAIN-tls"
echo ""
echo "🔧 Cleanup Command:"
echo "   ./cleanup.sh $SUBDOMAIN"
