#!/bin/bash
# Quick cleanup script for RKE2 ingress-nginx conflicts
# Run this if the migration playbook fails and you need to clean up manually

set -e

echo "Cleaning up RKE2 ingress-nginx components..."

export KUBECONFIG=~/.kube/config

# First, remove the DaemonSet (this is the critical one!)
echo "Removing RKE2 ingress-nginx DaemonSet..."
kubectl delete daemonset -n kube-system rke2-ingress-nginx-controller --ignore-not-found=true

# Remove deployments and services
kubectl delete deployment -n kube-system rke2-ingress-nginx-controller --ignore-not-found=true
kubectl delete service -n kube-system rke2-ingress-nginx-controller --ignore-not-found=true
kubectl delete service -n kube-system rke2-ingress-nginx-controller-admission --ignore-not-found=true
kubectl delete configmap -n kube-system rke2-ingress-nginx-controller --ignore-not-found=true
kubectl delete configmap -n kube-system chart-content-rke2-ingress-nginx --ignore-not-found=true
kubectl delete serviceaccount -n kube-system rke2-ingress-nginx --ignore-not-found=true

# Remove cluster-wide resources that conflict with upstream chart
echo "Removing conflicting cluster-wide resources..."
kubectl delete ingressclass nginx --ignore-not-found=true
kubectl delete clusterrole rke2-ingress-nginx --ignore-not-found=true
kubectl delete clusterrolebinding rke2-ingress-nginx --ignore-not-found=true

# Remove any admission webhook configurations
kubectl delete validatingwebhookconfiguration rke2-ingress-nginx-admission --ignore-not-found=true
kubectl delete mutatingwebhookconfiguration rke2-ingress-nginx-admission --ignore-not-found=true

# Remove any jobs related to RKE2 ingress-nginx
kubectl delete job -n kube-system rke2-ingress-nginx-admission-create --ignore-not-found=true
kubectl delete job -n kube-system rke2-ingress-nginx-admission-patch --ignore-not-found=true

echo "Waiting for DaemonSet pods to terminate..."
for i in {1..30}; do
  pod_count=$(kubectl get pods -n kube-system --selector=app.kubernetes.io/name=ingress-nginx --no-headers 2>/dev/null | wc -l)
  if [ "$pod_count" -eq 0 ]; then
    echo "✅ All RKE2 ingress-nginx pods have been terminated"
    break
  fi
  echo "Waiting for $pod_count RKE2 ingress pods to terminate... (attempt $i/30)"
  sleep 2
done

echo "Verification - checking for remaining conflicts:"
kubectl get ingressclass nginx 2>/dev/null && echo "❌ WARNING: nginx IngressClass still exists!" || echo "✅ nginx IngressClass removed"
kubectl get daemonset -n kube-system rke2-ingress-nginx-controller 2>/dev/null && echo "❌ WARNING: RKE2 DaemonSet still exists!" || echo "✅ RKE2 ingress DaemonSet removed"
kubectl get pods -n kube-system --selector=app.kubernetes.io/name=ingress-nginx 2>/dev/null | grep -v "No resources" && echo "❌ WARNING: RKE2 ingress pods still running!" || echo "✅ RKE2 ingress pods terminated"

echo ""
echo "🎯 Cleanup complete! The playbook should now be able to proceed with Helm installation."
