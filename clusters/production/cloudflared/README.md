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
   - svr.aac.gd, svr.aacg.dev → stremio-service.production:80

## Troubleshooting

1. Check cloudflared pods are running:
```bash
kubectl get pods -n cloudflared
```

2. Check cloudflared logs:
```bash
kubectl logs -n cloudflared -l app=cloudflared
```

3. Verify nginx-ingress connectivity:
```bash
kubectl exec -n cloudflared deploy/cloudflared -- curl -H "Host: svr.aacg.dev" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

```bash
kubectl exec -n cloudflared deploy/cloudflared -- curl -H "Host: svr.aac.gd" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```
