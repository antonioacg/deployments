# Debug Pod

The debug pod is a utility container that provides network troubleshooting tools for debugging Kubernetes networking issues. It uses the `nicolaka/netshoot` image which includes many networking tools like:

- curl
- wget
- dig
- nslookup
- iperf
- tcpdump
- netcat
- and many more

## Usage

The debug pod is automatically deployed in the production namespace. To use it:

1. Connect to the pod:
```bash
kubectl exec -it debug -n production -- /bin/bash
```

2. Common debugging examples:

Check DNS resolution:
```bash
dig stremio-service.production.svc.cluster.local
```

Test HTTP connectivity to Stremio:
```bash
curl http://stremio-service
```

Check network connectivity:
```bash
ping stremio-service
```

Monitor network traffic:
```bash
tcpdump -i any port 80
```

## Lifecycle

The pod runs continuously with a sleep command for 3600 seconds (1 hour). If you need to restart it:

```bash
kubectl delete pod debug -n production
kubectl apply -f debug-pod.yaml
```
