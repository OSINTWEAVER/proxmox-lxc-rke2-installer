# Rancher Management Console Access

## Quick Access

**Rancher UI**: https://rancher.octostar.lan
**Username**: admin
**Bootstrap Password**: admin123

## DNS Configuration Required

Add the following to your DNS or hosts file:
```
10.14.100.1  rancher.octostar.lan
```

### Windows hosts file:
`C:\Windows\System32\drivers\etc\hosts`

### Linux/macOS hosts file:
`/etc/hosts`

## First Login Steps

1. Browse to https://rancher.octostar.lan
2. Accept the self-signed certificate warning
3. Login with:
   - Username: `admin`
   - Password: `admin123`
4. Follow the setup wizard to:
   - Set a new secure password
   - Configure server URL
   - Accept license agreement

## Rancher Features Available

- **Cluster Management**: Import and manage existing Kubernetes clusters
- **Project/Namespace Management**: Organize resources with projects
- **Application Catalog**: Deploy apps from Helm charts
- **User Management**: RBAC, authentication providers
- **Monitoring & Logging**: Built-in Prometheus and Grafana
- **Backup & Restore**: Cluster backup solutions
- **Service Mesh**: Istio integration
- **CI/CD**: Fleet GitOps deployments

## CLI Access

You can also manage Rancher via kubectl:
```bash
# Check Rancher pods
kubectl get pods -n cattle-system

# Check Rancher services
kubectl get svc -n cattle-system

# View Rancher logs
kubectl logs -n cattle-system deployment/rancher

# Scale Rancher (if needed)
kubectl scale -n cattle-system deployment/rancher --replicas=1
```

## Security Notes

- **Change default password immediately after first login**
- **Configure proper SSL certificates for production**
- **Enable MFA for admin users**
- **Regularly update Rancher to latest version**
- **Review and configure network policies**

## Troubleshooting

### Common Issues:
1. **Can't access Rancher UI**:
   - Check DNS/hosts file configuration
   - Verify rancher.octostar.lan resolves to 10.14.100.1
   - Check ingress controller is running

2. **SSL Certificate warnings**:
   - Normal for self-signed certificates
   - Configure proper certificates for production

3. **Rancher pods not starting**:
   - Check node resources (CPU/memory)
   - Review pod logs: `kubectl logs -n cattle-system deployment/rancher`
   - Check persistent volume availability

### Support Commands:
```bash
# Full Rancher status
kubectl get all -n cattle-system

# Rancher configuration
kubectl get cm -n cattle-system

# Rancher secrets
kubectl get secrets -n cattle-system

# Ingress controller status
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```
