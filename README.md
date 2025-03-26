# Deployments Setup on Ubuntu Server

This guide explains a streamlined, GitOps-driven deployment using Flux in read-only mode for a private repository. The configuration ensures that the "production" namespace, persistent storage, and application resources are deployed in the correct sequence.

## Prerequisites

- An Ubuntu server with Git installed.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed and configured.
- [Flux CLI](https://fluxcd.io/docs/installation/) installed.
- Access to a Kubernetes cluster.
- A GitHub token (`GITHUB_TOKEN`) with read access for your private repository.
- [cert-manager](https://cert-manager.io/docs/installation/) installed in your cluster.

## Setup Instructions

1. **DNS Setup**

   Ensure your domain (svr.aacg.dev) points to your cluster's ingress controller IP:
   ```bash
   # Get ingress IP
   kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. **Clone the Repository**

   Clone the repository using your GitHub credentials:
   ```bash
   export GITHUB_TOKEN=your_token_here
   git clone https://antonioacg:$GITHUB_TOKEN@github.com/antonioacg/deployments.git
   cd deployments
   ```

3. **Configure Let's Encrypt Email**

   Update the ClusterIssuer configuration with your email:
   ```bash
   # Edit clusters/production/cert-manager/letsencrypt-prod.yaml
   # Replace 'your-email@example.com' with your actual email
   ```

4. **Create Git Authentication Secret**

   Create a Kubernetes secret in the `flux-system` namespace:
   ```bash
   kubectl create secret generic flux-git-deploy \
     --from-literal=username=antonioacg \
     --from-literal=password=$GITHUB_TOKEN \
     -n flux-system
   ```

5. **Deploy with Flux**

   Install Flux and configure the Git source along with your production configuration:
   ```bash
   flux install
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

6. **Verify the Deployment**

   Check certificate issuance and ingress status:
   ```bash
   # Check certificate status
   kubectl get certificate -n production
   kubectl get certificaterequest -n production
   kubectl get challenge -n production

   # Check ingress
   kubectl get ingress -n production
   
   # Verify TLS certificate
   curl -v https://svr.aacg.dev
   ```

## Troubleshooting

### Certificate Issues
- Check cert-manager logs:
  ```bash
  kubectl logs -n cert-manager deploy/cert-manager
  ```
- Verify ClusterIssuer status:
  ```bash
  kubectl get clusterissuer letsencrypt-prod -o yaml
  ```
- Check challenge status:
  ```bash
  kubectl get challenges -n production
  ```

## Folder Structure Overview

- **namespaces/production.yaml:** Defines the production namespace and its kustomization is in `namespaces/kustomization.yaml`.
- **clusters/production/pvc/stremio-pvc.yaml:** PersistentVolumeClaim for Stremio.
- **clusters/production/apps/stremio.yaml:** Deployment and Service for Stremio.
- **clusters/production/pvc.yaml & apps.yaml:** Flux kustomizations for PVC and Apps (with dependencies).
- **clusters/production/kustomization.yaml:** Aggregates the PVC and Apps kustomizations.
