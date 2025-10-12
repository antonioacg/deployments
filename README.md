# GitOps Deployments Repository

**Part of a 3-repository zero-secrets GitOps platform**

This repository contains Kubernetes manifests for a complete zero-secrets architecture using Vault + External Secrets Operator. It works as part of a larger platform with:

- **infra-management**: Bootstrap orchestrator (runs the deployment)
- **infra**: Terraform infrastructure and Vault secret management  
- **deployments**: This repository (Kubernetes manifests)

## How to Deploy

This repository cannot be used standalone. To deploy the complete platform:

1. Go to the infra-management repository
2. Run the bootstrap script with your GitHub token
3. The platform automatically deploys all components including the manifests from this repo

## Zero-Secrets Architecture

All secrets flow: **Terraform** → **Vault** → **External Secrets** → **Kubernetes**

- ✅ **No secrets in Git repositories** (ever, anywhere)
- ✅ **Vault manages all secrets** with centralized storage
- ✅ **External Secrets** syncs from Vault to Kubernetes automatically
- ✅ **Flux CD** provides GitOps delivery with read-only Git access

### Infrastructure Components
- **Vault**: Secret management with Bank-Vaults operator (automated unsealing)
- **External Secrets Operator**: Syncs secrets from Vault to Kubernetes
- **Cloudflared**: Secure tunnel to Cloudflare (optional)

### Applications
- **Stremio**: Example media streaming application

### Repository Structure
```
clusters/production/
├── infrastructure/          # Core platform components
│   ├── vault/              # Vault with Bank-Vaults operator
│   ├── external-secrets/   # External Secrets Operator
│   └── cloudflared/        # Cloudflare tunnel
├── applications/           # User applications
└── kustomization.yaml     # Root Flux configuration
```

## Making Changes

To update deployments:
1. Edit Kubernetes manifests in this repository
2. Commit and push to main branch  
3. Flux automatically syncs changes to the cluster
4. External Secrets provides secrets automatically (no manual secret management needed)

## Troubleshooting

### Check Flux status
```bash
flux get sources git
flux get kustomizations
```

### Debug External Secrets
```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

### Vault issues
```bash
kubectl logs -n vault -l app.kubernetes.io/name=vault
kubectl exec -n vault vault-0 -- vault status
```

**Common Issues:**
- If deployments aren't syncing: Check `flux get sources git` 
- If secrets are missing: Verify `kubectl get externalsecrets -A`
- If Vault is sealed: Check `kubectl exec -n vault vault-0 -- vault status`