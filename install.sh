#!/bin/bash
set -e

echo "Starting Flux installation script..."
echo "Checking required environment variables..."

# Check required env vars
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi
echo "✓ GITHUB_TOKEN is set"

if [ -z "$SOPS_AGE_KEY_FILE" ]; then
    echo "Error: SOPS_AGE_KEY_FILE environment variable is required"
    exit 1
fi
echo "✓ SOPS_AGE_KEY_FILE is set"
echo "Checking if SOPS_AGE_KEY_FILE exists at: $SOPS_AGE_KEY_FILE"
if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
    echo "Error: SOPS_AGE_KEY_FILE does not exist at $SOPS_AGE_KEY_FILE"
    exit 1
fi
echo "✓ SOPS_AGE_KEY_FILE exists"

echo "Checking for required tools..."
# Check if kubectl is installed
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required but not installed."
    exit 1
fi
echo "✓ kubectl is installed"

# Install flux if not present
if ! command -v flux >/dev/null 2>&1; then
    echo "Flux CLI not found - starting installation..."
    # Detect OS and architecture
    OS="$(uname | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    echo "Detected OS: $OS"
    echo "Detected architecture: $ARCH"
    
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) echo "Error: Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    echo "Mapped architecture: $ARCH"

    # Install Flux
    echo "Downloading Flux installation script..."
    FLUX_INSTALL_SCRIPT_URL="https://fluxcd.io/install.sh"
    if command -v curl >/dev/null 2>&1; then
        echo "Using curl to download Flux..."
        curl -s $FLUX_INSTALL_SCRIPT_URL | sudo bash
    elif command -v wget >/dev/null 2>&1; then
        echo "Using wget to download Flux..."
        wget -qO- $FLUX_INSTALL_SCRIPT_URL | sudo bash
    else
        echo "Error: curl or wget required to install Flux"
        exit 1
    fi
    echo "✓ Flux CLI installed successfully"
else
    echo "✓ Flux CLI already installed"
fi

# Install Flux components
echo "Installing Flux components in the cluster..."
flux install
echo "✓ Flux components installed"

# Create flux-system namespace
echo "Creating flux-system namespace..."
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
echo "✓ flux-system namespace ready"

# Create Age secret for SOPS
echo "Creating Age secret for SOPS decryption..."
kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey=$SOPS_AGE_KEY_FILE \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✓ SOPS Age secret created"

# Create Git repository secret
echo "Creating Git repository secret for authentication..."
kubectl create secret generic flux-git-deploy \
    --namespace=flux-system \
    --from-literal=username=antonioacg \
    --from-literal=password=$GITHUB_TOKEN \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Git repository secret created"

# Apply GitRepository and Kustomization
echo "Configuring Flux with Git source and Kustomization..."
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: deployments
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  secretRef:
    name: flux-git-deploy
  url: https://github.com/antonioacg/deployments
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: production
  namespace: flux-system
spec:
  interval: 5m
  path: "./clusters/production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: deployments
  decryption:
    provider: sops
    secretRef:
      name: sops-age
EOF
echo "✓ GitRepository and Kustomization configured"

echo "Installation complete! Running verification..."
flux get all --all-namespaces
echo "✓ Setup verification completed"
echo "Flux installation and configuration finished successfully!"