# Deployments Setup on Ubuntu Server

This guide explains a streamlined, GitOps-driven deployment using Flux in read-only mode for a private repository. The configuration ensures that the "production" namespace, persistent storage, and application resources are deployed in the correct sequence.

## Prerequisites

- An Ubuntu server with Git installed.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed and configured.
- [Flux CLI](https://fluxcd.io/docs/installation/) installed.
- Access to a Kubernetes cluster.
- A GitHub token (`GITHUB_TOKEN`) with read access for your private repository.

## Setup Instructions

1. **Clone the Repository**

   Clone the repository using your GitHub credentials:
   ```bash
   export GITHUB_USER=your_github_username
   export GITHUB_TOKEN=your_token_here
   git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/deployments.git
   cd deployments
   ```

2. **Create Git Authentication Secret**

   Create a Kubernetes secret in the `flux-system` namespace:
   ```bash
   kubectl create secret generic flux-git-deploy \
     --from-literal=username=$GITHUB_USER \
     --from-literal=password=$GITHUB_TOKEN \
     -n flux-system
   ```

3. **Deploy with Flux**

   Install Flux and configure the Git source along with your production configuration:
   ```bash
   flux install
   flux create source git deployments \
     --url=https://github.com/$GITHUB_USER/deployments.git \
     --branch=main \
     --interval=1m \
     --secret-ref=flux-git-deploy

   flux create kustomization production \
     --source=deployments \
     --path="./clusters/production" \
     --prune=true \
     --wait=true \
     --interval=1m
   ```

4. **Verify the Deployment**

   Check that all resources are running in the `production` namespace:
   ```bash
   kubectl get all -n production
   ```

## Folder Structure Overview

- **namespaces/production.yaml:** Defines the production namespace and its kustomization is in `namespaces/kustomization.yaml`.
- **clusters/production/pvc/stremio-pvc.yaml:** PersistentVolumeClaim for Stremio.
- **clusters/production/apps/stremio.yaml:** Deployment and Service for Stremio.
- **clusters/production/pvc.yaml & apps.yaml:** Flux kustomizations for PVC and Apps (with dependencies).
- **clusters/production/kustomization.yaml:** Aggregates the PVC and Apps kustomizations.
