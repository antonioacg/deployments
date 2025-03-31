# Deployments Setup on Ubuntu Server

This guide explains a streamlined, GitOps-driven deployment using Flux in read-only mode for managing a Kubernetes cluster through Git.

## Prerequisites

1. An Ubuntu server with Git installed
2. Access to a Kubernetes cluster 
3. A GitHub token (`GITHUB_TOKEN`) with read access for your private repository

### Install kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Install Flux CLI
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

## Setup Instructions

1. **Install Flux**
   ```bash
   flux install
   ```

2. **Create Git Repository Secret**
   ```bash
   kubectl create secret generic flux-git-deploy \
     --namespace=flux-system \
     --from-literal=username=antonioacg \
     --from-literal=password=$GITHUB_TOKEN
   ```

3. **Configure Flux with Git Source**
   ```bash
   flux create source git deployments \
     --url=https://antonioacg:$GITHUB_TOKEN@github.com/antonioacg/deployments \
     --branch=main \
     --secret-ref=flux-git-deploy

   flux create kustomization production \
     --source=deployments \
     --path="./clusters/production" \
     --prune=true \
     --wait=false \
     --timeout=5m \
     --interval=1m
   ```

## Infrastructure Overview

- **Traffic Flow**:
  1. Internet → Cloudflare
  2. Cloudflare → Cloudflared Tunnel
  3. Cloudflared → Nginx Ingress
  4. Nginx Ingress → Services

- **Key Components**:
  - Cloudflared: Manages secure tunnel to Cloudflare
  - Nginx Ingress: Internal traffic routing
  - Flux: GitOps deployment management

## Folder Structure

- **namespaces/**: Namespace definitions
- **clusters/production/**:
  - **nginx-ingress/**: Ingress controller and routes
  - **cloudflared/**: Cloudflare tunnel configuration
  - **apps/**: Application deployments
  - **pvc/**: Persistent volume claims

## Troubleshooting

1. **Check Flux Status**:
   ```bash
   flux get all
   ```

2. **Check Pod Status**:
   ```bash
   kubectl get pods -A
   ```

3. **View Component Logs**:
   ```bash
   # Cloudflared logs
   kubectl logs -n cloudflared -l app=cloudflared

   # Nginx ingress logs
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```
