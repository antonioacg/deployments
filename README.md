# Deployments Setup on Ubuntu Server

This guide explains a streamlined, GitOps-driven deployment using Flux in read-only mode for managing a Kubernetes cluster through Git.

## Prerequisites

1. An Ubuntu server with Git installed
2. Access to a Kubernetes cluster 
3. A GitHub token (`GITHUB_TOKEN`) with read access for your private repository

## Installation

1. **Set Required Environment Variables**:
   ```bash
   export GITHUB_TOKEN="your-github-token"
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```

2. **Install SOPS and Age**:
   ```bash
   ./install-sops-age.sh
   ```

3. **Install Flux and Configure Cluster**:
   ```bash
   ./install.sh
   ```

4. **Verify the Installation**:
   ```bash
   flux get all --all-namespaces
   ```

## Retrieving Your Public Key

After installing SOPS and Age, your public key is stored in the keys file. To extract it:

```bash
grep '^# public key:' $SOPS_AGE_KEY_FILE | cut -d' ' -f4
```

Use this public key (starts with `age1...`) when encrypting your secrets.

> **Important**: 
> - Never commit your private key file to Git
> - Back up your `keys.txt` file securely
> - The key file is located at `~/.config/sops/age/keys.txt`

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
  - SOPS: Secret encryption
  - Age: Encryption key management

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

4. **Verify SOPS/Age Setup**:
   ```bash
   # Check SOPS version
   sops --version

   # Verify Age key file
   ls -l $SOPS_AGE_KEY_FILE

   # Test SOPS encryption
   echo "secret: test" | sops --encrypt --age $(grep "^# public key:" $SOPS_AGE_KEY_FILE | cut -d' ' -f4) /dev/stdin
   ```
