# GitOps Deployments Repository

**Part of a 3-repository Flux-first GitOps platform**

This repository contains Kubernetes manifests for the platform. Flux CD syncs these manifests to the cluster automatically.

## Platform Repositories

- **infra-management**: Bootstrap scripts (Phases 0-2)
- **infra**: Bootstrap Terraform (state migration, Flux install)
- **deployments**: This repository - all post-bootstrap infrastructure and apps

## How to Deploy

This repository cannot be used standalone. To deploy the complete platform:

1. Go to the infra-management repository
2. Run the bootstrap script with your GitHub token
3. Phase 2 installs Flux, which syncs this repo automatically

## Zero-Secrets Architecture

All secrets flow: **Git (manifests)** → **Flux** → **Vault** → **External Secrets** → **Kubernetes**

- No secrets in Git repositories (ever, anywhere)
- Vault manages all secrets with centralized storage
- External Secrets syncs from Vault to Kubernetes automatically
- Flux CD provides GitOps delivery

## Repository Structure

```
clusters/production/
├── flux-system/             # Flux controllers
├── infrastructure/          # Platform services (Flux managed)
│   ├── vault/              # Vault with Bank-Vaults operator
│   ├── external-secrets/   # External Secrets Operator
│   └── ingress/            # Ingress controllers
└── applications/           # Business applications
```

## Making Changes

1. Edit Kubernetes manifests in this repository
2. Commit and push to main branch
3. Flux automatically syncs changes to the cluster
4. External Secrets provides secrets automatically

## Verification

```bash
# Check Flux status
flux get sources git
flux get kustomizations -A

# Check infrastructure
kubectl get pods -n vault
kubectl get pods -n external-secrets-system

# Check External Secrets
kubectl get externalsecrets -A
kubectl get clustersecretstore
```

## Troubleshooting

**Deployments not syncing:**
```bash
flux get sources git
kubectl logs -n flux-system -l app=source-controller
```

**Secrets missing:**
```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

**Vault issues:**
```bash
kubectl get pods -n vault
kubectl logs -n vault -l app.kubernetes.io/name=vault
kubectl exec -n vault vault-0 -- vault status
```
