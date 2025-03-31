# Cloudflared Setup

## Prerequisites

1. Create a tunnel in the Cloudflare Zero Trust dashboard
2. Copy the tunnel token from the dashboard
3. Configure the DNS records in Cloudflare to point to your tunnel

## Installation

1. Create the credentials secret using your tunnel token:
```bash
kubectl create secret generic cloudflared-credentials \
  --from-literal=token="eyJhI...long-token-string...dSayJ9" \
  -n cloudflared
```

Note: The token value should be the raw token string without any prefix or key name.

## Configuration

The configmap contains the routing rules for your tunnel. All traffic is routed through nginx-ingress controller:

```yaml
ingress:
- hostname: *.aacg.dev
  service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
- service: http_status:404  # Catch-all rule
```

## Architecture

1. Cloudflared tunnel receives traffic for *.aac.gd and *.aacg.dev domains
2. All traffic is forwarded to nginx-ingress controller
3. Nginx-ingress routes traffic based on Host header to appropriate services
4. Current routes:
   - stremio.aac.gd, stremio.aacg.dev → stremio-service.production:80

## Troubleshooting

1. Check cloudflared pods are running:
```bash
kubectl get pods -n cloudflared
```

2. Check cloudflared logs:
```bash
kubectl logs -n cloudflared -l app=cloudflared
```

3. Verify tunnel connectivity:
```bash
# Check tunnel status (using token authentication)
kubectl exec -n cloudflared deploy/cloudflared -- cloudflared tunnel run --token $(kubectl get secret -n cloudflared cloudflared-credentials -o jsonpath='{.data.token}' | base64 -d) --url http://localhost:2000 --inspect

# List active connections
kubectl exec -n cloudflared deploy/cloudflared -- curl http://localhost:2000/metrics | grep cloudflared_tunnel_connection
```

4. Test nginx-ingress connectivity:
```bash
# Test primary domain
kubectl exec -n cloudflared deploy/cloudflared -- curl -v -H "Host: stremio.aac.gd" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local

# Test secondary domain
kubectl exec -n cloudflared deploy/cloudflared -- curl -v -H "Host: stremio.aacg.dev" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

5. Verify tunnel configuration:
```bash
# Check config file
kubectl exec -n cloudflared deploy/cloudflared -- cat /etc/cloudflared/config/config.yaml

# Check environment variables
kubectl exec -n cloudflared deploy/cloudflared -- env | grep TUNNEL
```

6. Check nginx-ingress logs:
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100
```

7. Verify DNS resolution:
```bash
# Inside cloudflared pod
kubectl exec -it -n cloudflared deploy/cloudflared -- nslookup ingress-nginx-controller.ingress-nginx.svc.cluster.local

# Check if services are discoverable
kubectl exec -it -n cloudflared deploy/cloudflared -- curl -v http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
```

Common Issues:

1. **Tunnel Authentication Issues**
   - Verify tunnel token is correctly set in secret: 
     ```bash
     kubectl get secret -n cloudflared cloudflared-credentials -o jsonpath='{.data.token}' | base64 -d
     ```
   - Check if token is mounted properly:
     ```bash
     kubectl exec -n cloudflared deploy/cloudflared -- env | grep TUNNEL_TOKEN
     ```

2. **Connection Refused**
   - Check if nginx-ingress pods are running
   - Verify service ports are correct
   - Check firewall rules

3. **DNS Resolution Failed**
   - Verify CoreDNS is running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
   - Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`

4. **Certificate Errors**
   - Verify Cloudflare SSL/TLS mode is set to "Full" or "Flexible"
   - Check if certificates are properly configured in nginx-ingress

5. **502 Bad Gateway**
   - Check if backend services are running and healthy
   - Verify service endpoints: `kubectl get endpoints -n <namespace>`
