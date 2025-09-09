#!/bin/bash
# RKE2 Cluster SSL Web Test Deployment Script

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <subdomain.domain.com> \"<custom message>\""
    echo "Example: $0 test.example.com \"Welcome to my SSL test page!\""
    exit 1
fi

SUBDOMAIN="$1"
MESSAGE="$2"

# Extract domain from subdomain
DOMAIN=$(e# Get node IPs for reference
NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')ho "$SUBDOMAIN" | cut -d'.' -f2-)

# Sanitize domain for certificate secret name (replace dots with hyphens)
SANITIZED_DOMAIN=$(echo "$DOMAIN" | sed 's/\./-/g')

# Sanitize subdomain for Kubernetes resource names (replace dots with hyphens)
SANITIZED_SUBDOMAIN=$(echo "$SUBDOMAIN" | sed 's/\./-/g')

echo "🚀 Deploying SSL Test Webapp to RKE2 Cluster"
echo "==============================================="
echo "Subdomain: $SUBDOMAIN"
echo "Domain: $DOMAIN"
echo "Custom Message: $MESSAGE"
echo ""

# Set kubeconfig (use local kubeconfig if running from local machine)
if [ -f ~/.kube/config ]; then
    export KUBECONFIG=~/.kube/config
elif [ -f /etc/rancher/rke2/rke2.yaml ]; then
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
else
    echo "❌ No kubeconfig found! Please ensure you have fetched the kubeconfig first."
    echo "   Run: .\\scripts\\fetch_kubeconfig.bat inventories\\hosts-iris.ini (or your inventory)"
    exit 1
fi

echo "📋 Cluster Status:"
kubectl get nodes -o wide

echo ""
echo "🔒 Checking SSL Certificate Status:"
kubectl get certificates --all-namespaces | grep -E "(wildcard|$SANITIZED_DOMAIN)"

# Check for duplicate certificates
DUPLICATE_CERTS=$(kubectl get certificates --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "wildcard-$SANITIZED_DOMAIN" | wc -l)
if [ "$DUPLICATE_CERTS" -gt 1 ]; then
    echo "   ⚠️  Found $DUPLICATE_CERTS certificates with similar names. This may cause issues."
    kubectl get certificates --all-namespaces | grep "wildcard-$SANITIZED_DOMAIN"
    echo "   🧹 Cleaning up duplicate certificates..."
    # Delete the older/broken certificate (keep the one with the correct name)
    kubectl delete certificate wildcard-$SANITIZED_DOMAIN-tls -n default --ignore-not-found=true
    echo "   ✅ Duplicate certificate cleanup complete."
fi

# Wait for wildcard certificate to be ready
echo ""
echo "⏳ Waiting for wildcard certificate to be ready..."
CERT_READY=false
for i in {1..30}; do
    if kubectl get certificate wildcard-$SANITIZED_DOMAIN -n default 2>/dev/null | grep -q "True"; then
        echo "   ✅ Wildcard certificate is ready!"
        CERT_READY=true
        break
    else
        echo "   ⏳ Certificate not ready yet (attempt $i/30)..."
        sleep 10
    fi
done

if [ "$CERT_READY" = false ]; then
    echo "   ⚠️  Certificate still not ready after 5 minutes. Proceeding anyway..."
    echo "   The ingress may use the default fake certificate until the real certificate is issued."
    echo ""
    echo "   🔍 Certificate Troubleshooting:"
    kubectl describe certificate wildcard-$SANITIZED_DOMAIN -n default | grep -E "(Status|Reason|Message|Events)" -A 10 || echo "   Could not get certificate details"
    echo ""
    echo "   📋 Certificate Events:"
    kubectl get events -n default --field-selector reason=CreateCertificate,reason=UpdateCertificate,reason=IssueCertificate -o wide | tail -10 || echo "   No certificate events found"
    echo ""
    echo "   🔐 ACME Challenges:"
    kubectl get challenges -n default -o wide || echo "   No challenges found"
    echo ""
    echo "   📜 Certificate Orders:"
    kubectl get orders -n default -o wide || echo "   No orders found"
    echo ""
    echo "   🌐 DNS Check - Make sure these records exist:"
    echo "      $SUBDOMAIN -> Your cluster IP"
    echo "      *.$DOMAIN -> Your cluster IP"
    echo ""
    echo "   🧪 Test DNS resolution:"
    echo "      nslookup $SUBDOMAIN"
    echo "      nslookup test.$DOMAIN"
    echo ""
    echo "   🔧 Check cert-manager status:"
    kubectl get pods -n cert-manager"
    kubectl logs -n cert-manager deployment/cert-manager --tail=20 | grep -i error || echo "   No recent errors in cert-manager logs"
fi

echo ""
echo "🧹 Cleaning up any existing SSL test webapp for $SUBDOMAIN..."

# Clean up existing resources for this subdomain
echo "   Deleting ConfigMap..."
kubectl delete configmap ssl-test-html-$SANITIZED_SUBDOMAIN --ignore-not-found=true

echo "   Deleting Deployment..."
kubectl delete deployment ssl-test-webapp-$SANITIZED_SUBDOMAIN --ignore-not-found=true

echo "   Deleting Service..."
kubectl delete service ssl-test-webapp-service-$SANITIZED_SUBDOMAIN --ignore-not-found=true

echo "   Deleting Ingress..."
kubectl delete ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN --ignore-not-found=true

# Wait longer for cleanup to complete
echo "   Waiting for cleanup to complete..."
sleep 5

# Verify cleanup
echo "   Verifying cleanup..."
if kubectl get configmap ssl-test-html-$SANITIZED_SUBDOMAIN 2>/dev/null; then
    echo "   ⚠️  ConfigMap still exists, forcing deletion..."
    kubectl delete configmap ssl-test-html-$SANITIZED_SUBDOMAIN --force --grace-period=0 2>/dev/null || true
fi

if kubectl get deployment ssl-test-webapp-$SANITIZED_SUBDOMAIN 2>/dev/null; then
    echo "   ⚠️  Deployment still exists, forcing deletion..."
    kubectl delete deployment ssl-test-webapp-$SANITIZED_SUBDOMAIN --force --grace-period=0 2>/dev/null || true
fi

if kubectl get service ssl-test-webapp-service-$SANITIZED_SUBDOMAIN 2>/dev/null; then
    echo "   ⚠️  Service still exists, forcing deletion..."
    kubectl delete service ssl-test-webapp-service-$SANITIZED_SUBDOMAIN --force --grace-period=0 2>/dev/null || true
fi

if kubectl get ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN 2>/dev/null; then
    echo "   ⚠️  Ingress still exists, forcing deletion..."
    kubectl delete ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN --force --grace-period=0 2>/dev/null || true
fi

# Final wait
sleep 3

echo ""
echo "🌐 Generating SSL test webapp YAML..."

# Generate the YAML file
YAML_FILE="test-ssl-webapp-$SANITIZED_SUBDOMAIN.yaml"
cat > "$YAML_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssl-test-html-$SANITIZED_SUBDOMAIN
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>$SUBDOMAIN - SSL Test</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                text-align: center;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
                backdrop-filter: blur(10px);
                box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
            }
            h1 {
                margin-bottom: 20px;
                font-size: 2.5em;
            }
            p {
                font-size: 1.2em;
                margin: 10px 0;
            }
            .status {
                background: rgba(0, 255, 0, 0.2);
                padding: 10px;
                border-radius: 5px;
                margin: 20px 0;
            }
            a {
                color: #ffd700;
                text-decoration: none;
                font-weight: bold;
            }
            a:hover {
                text-decoration: underline;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>&#128274; SSL Configuration Success</h1>
            <div class="status">
                <p>&#9989; HTTPS Certificate: Active</p>
                <p>&#127760; Domain: $SUBDOMAIN</p>
                <p>&#128279; SSL Certificate: wildcard-$SANITIZED_DOMAIN-tls</p>
            </div>
            <p>$MESSAGE</p>
            <p><small>Test completed at $(date)</small></p>
        </div>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ssl-test-webapp-$SANITIZED_SUBDOMAIN
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ssl-test-webapp
      subdomain: $SUBDOMAIN
  template:
    metadata:
      labels:
        app: ssl-test-webapp
        subdomain: $SUBDOMAIN
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: ssl-test-html-$SANITIZED_SUBDOMAIN
---
apiVersion: v1
kind: Service
metadata:
  name: ssl-test-webapp-service-$SANITIZED_SUBDOMAIN
  namespace: default
spec:
  selector:
    app: ssl-test-webapp
    subdomain: $SUBDOMAIN
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $SUBDOMAIN
    secretName: wildcard-$SANITIZED_DOMAIN-tls
  rules:
  - host: $SUBDOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ssl-test-webapp-service-$SANITIZED_SUBDOMAIN
            port:
              number: 80
EOF

echo "📄 Generated YAML file: $YAML_FILE"

echo ""
echo "🌐 Deploying test webapp..."
kubectl apply -f "$YAML_FILE"

echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/ssl-test-webapp-$SANITIZED_SUBDOMAIN

echo ""
echo "📊 Deployment Status:"
kubectl get pods,svc,ingress -l app=ssl-test-webapp,subdomain=$SUBDOMAIN

echo ""
echo "🔍 Certificate Details:"
kubectl describe ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN | grep -A 5 "TLS:" || echo "   No TLS info found"

echo ""
echo "🔒 Certificate Secret Status:"
kubectl get secret wildcard-$SANITIZED_DOMAIN-tls -n default 2>/dev/null || echo "   Certificate secret not found"

echo ""
echo "🎯 Access Information:"
echo "======================================"

# Get node IPs for reference
NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

echo "HTTPS Access - SSL Enabled:"
echo "   https://$SUBDOMAIN"

echo ""
echo "Local Access (if you add to /etc/hosts):"
echo "   Add to your local /etc/hosts file:"
for ip in $NODE_IPS; do
    echo "   $ip $SUBDOMAIN"
done
echo "   Then access: https://$SUBDOMAIN"

echo ""
echo "🔍 Pod Details:"
kubectl get pods -l app=ssl-test-webapp,subdomain=$SUBDOMAIN -o wide

echo ""
echo "📝 Service Details:"
kubectl describe svc ssl-test-webapp-service-$SANITIZED_SUBDOMAIN

echo ""
echo "✅ SSL Test Deployment Complete!"
echo ""
echo "🎉 Features:"
echo "   - Full HTTPS with Let's Encrypt SSL certificate"
echo "   - Custom message: \"$MESSAGE\""
echo "   - Modern responsive design"
echo "   - Automatic SSL redirect (HTTP -> HTTPS)"
echo ""
echo "🔒 Final Certificate Check:"
kubectl get ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || echo "   No TLS secret found in ingress"
echo ""
echo "🌐 Test your SSL certificate at: https://$SUBDOMAIN"
echo ""
echo "🛠️ Manual Certificate Debugging Commands:"
echo "   kubectl describe certificate wildcard-$SANITIZED_DOMAIN -n default"
echo "   kubectl get challenges -n default"
echo "   kubectl get orders -n default"
echo "   kubectl logs -n cert-manager deployment/cert-manager"
echo "   kubectl get events -n default --field-selector reason=CreateCertificate,reason=UpdateCertificate,reason=IssueCertificate"
echo ""
echo "🛠️ Troubleshooting:"
echo "   - Check pods: kubectl get pods -l app=ssl-test-webapp,subdomain=$SUBDOMAIN"
echo "   - Check logs: kubectl logs -l app=ssl-test-webapp,subdomain=$SUBDOMAIN"
echo "   - Check service: kubectl get svc ssl-test-webapp-service-$SANITIZED_SUBDOMAIN"
echo "   - Check ingress: kubectl get ingress ssl-test-webapp-ingress-$SANITIZED_SUBDOMAIN"
echo "   - Check certificate: kubectl get certificate wildcard-$SANITIZED_DOMAIN -n default"
echo "   - Check certificate secret: kubectl get secret wildcard-$SANITIZED_DOMAIN-tls -n default"
echo "   - Describe certificate: kubectl describe certificate wildcard-$SANITIZED_DOMAIN -n default"
echo "   - Port forward: kubectl port-forward svc/ssl-test-webapp-service-$SANITIZED_SUBDOMAIN 8080:80"
echo "     Then access: http://localhost:8080 (bypasses SSL for testing)"
