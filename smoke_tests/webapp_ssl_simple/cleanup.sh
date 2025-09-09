#!/bin/bash
# Cleanup SSL Webapp Deployment

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <subdomain.domain.com>"
    echo "Example: $0 test.example.com"
    exit 1
fi

SUBDOMAIN="$1"
DOMAIN=$(echo "$SUBDOMAIN" | cut -d'.' -f2-)
SANITIZED_DOMAIN=$(echo "$DOMAIN" | sed 's/\./-/g')
SANITIZED_SUBDOMAIN=$(echo "$SUBDOMAIN" | sed 's/\./-/g')

echo "🧹 Cleaning up SSL webapp: $SUBDOMAIN"
echo "====================================="

# Set kubeconfig
if [ -f ~/.kube/config ]; then
    export KUBECONFIG=~/.kube/config
elif [ -f /etc/rancher/rke2/rke2.yaml ]; then
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
else
    echo "❌ No kubeconfig found!"
    exit 1
fi

echo "🗑️  Deleting resources..."

# Delete resources
kubectl delete configmap ssl-test-html-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete configmap ssl-test-nginx-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete deployment ssl-test-webapp-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete service ssl-test-webapp-service-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete certificate $SANITIZED_SUBDOMAIN-cert --ignore-not-found=true
kubectl delete serviceaccount ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete clusterrole ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete clusterrolebinding ssl-test-cluster-reader-$SANITIZED_SUBDOMAIN --ignore-not-found=true
kubectl delete pvc ssl-test-cluster-stats-$SANITIZED_SUBDOMAIN --ignore-not-found=true

echo ""
echo "✅ Cleanup complete!"
