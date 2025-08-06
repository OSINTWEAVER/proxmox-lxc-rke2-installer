#!/bin/bash
# RKE2 Cluster Web Test Deployment Script

echo "🚀 Deploying Funny Test Webapp to RKE2 Cluster"
echo "==============================================="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

echo "📋 Cluster Status:"
kubectl get nodes -o wide

echo ""
echo "🌐 Deploying test webapp..."
kubectl apply -f test-webapp.yaml

echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/funny-webapp

echo ""
echo "📊 Deployment Status:"
kubectl get pods,svc,ingress -l app=funny-webapp

echo ""
echo "🎯 Access Information:"
echo "======================================"

# Get node IPs
NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
NODEPORT=$(kubectl get svc funny-webapp-service -o jsonpath='{.spec.ports[0].nodePort}')

echo "🌐 NodePort Access (Direct):"
for ip in $NODE_IPS; do
    echo "   http://$ip:$NODEPORT"
done

echo ""
echo "🏠 Local Access (if you add to /etc/hosts):"
echo "   Add to your local /etc/hosts file:"
for ip in $NODE_IPS; do
    echo "   $ip rke2-cluster.local cluster-test.local"
done
echo "   Then access: http://rke2-cluster.local:$NODEPORT"

echo ""
echo "🔍 Pod Details:"
kubectl get pods -l app=funny-webapp -o wide

echo ""
echo "📝 Service Details:"
kubectl describe svc funny-webapp-service

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🎉 Fun Features:"
echo "   - Click anywhere to change background color"
echo "   - Try the Konami Code: ↑↑↓↓←→←→BA for a surprise!"
echo "   - Responsive design works on mobile too"
echo ""
echo "🛠️ Troubleshooting:"
echo "   - Check pods: kubectl get pods -l app=funny-webapp"
echo "   - Check logs: kubectl logs -l app=funny-webapp"
echo "   - Check service: kubectl get svc funny-webapp-service"
echo "   - Port forward: kubectl port-forward svc/funny-webapp-service 8080:80"
echo "     Then access: http://localhost:8080"
