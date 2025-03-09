# Kubernetes Deployments Repository

This repository contains Kubernetes manifests managed by Flux CD for GitOps deployments.

## Prerequisites

- Kubernetes cluster
- kubectl configured
- GitHub repository containing your Kubernetes manifests
- GitHub personal access token with read-only permissions

## Installation

### 1. Install Flux CLI

MacOS:
```bash
brew install fluxcd/tap/flux
```

Debian/Ubuntu:
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

### 2. Configure Flux Components

```bash
# Set your GitHub details
export GITHUB_USER=<your-username>
export GITHUB_TOKEN=<your-token>

# Create namespace
kubectl create namespace flux-system

# Generate and apply core components
flux install \
  --export | kubectl apply -f -

# Configure Flux to watch your repository with authentication
flux create source git flux-system \
  --url=https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/deployments \
  --branch=main \
  --interval=1m \
  --export | kubectl apply -f -
```

### 3. Install ingress-nginx (Optional)

```bash
# Create namespace and install ingress
kubectl create namespace ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=30s
```

## How It Works

1. Flux components run in your cluster (installed via kubectl)
2. Flux watches your GitHub repository in read-only mode
3. Changes must be made through your normal Git workflow
4. Flux automatically detects and applies changes from the repository

## Repository Workflow

### How Flux Works with Git

1. **Repository Management**:
   - Flux does NOT clone the repository to your local machine
   - All Git operations happen inside the Flux pods in your cluster
   - Flux maintains its own temporary clone for syncing

2. **Typical Workflow**:
   ```bash
   # Clone repository for making changes
   git clone https://github.com/${GITHUB_USER}/deployments
   cd deployments

   # Make changes to your manifests
   vim clusters/production/apps/myapp.yaml

   # Push changes to GitHub
   git add .
   git commit -m "Update application configuration"
   git push

   # Flux automatically detects and applies changes
   # You can watch the sync:
   flux get all
   ```

3. **Data Flow**:
   ```
   Your Local Files → GitHub Repository ←-- READ ONLY --- Flux → Kubernetes Resources
   ```

## Verification and Troubleshooting

```bash
# Check Flux status
flux get all

# Check Flux logs
flux logs -n flux-system --level=error

# Verify source configuration
flux get sources git

# Check application deployments
kubectl get pods --all-namespaces
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces
kubectl get ingress --all-namespaces
```
