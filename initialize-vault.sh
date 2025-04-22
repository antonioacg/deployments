#!/bin/bash
# filepath: /Users/antoniocasagrande/git/deployments/initialize-vault.sh
set -e

# Check if required tools are installed
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required but not installed."
    exit 1
fi
echo "✓ kubectl is installed"

if ! command -v sops >/dev/null 2>&1; then
    echo "Error: sops is required but not installed."
    exit 1
fi
echo "✓ sops is installed"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed."
    exit 1
fi
echo "✓ jq is installed"

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

# Configuration
NAMESPACE="vault"
BACKUP_DIR="./vault-backup"
AGE_PUBLIC_KEY=$(grep '^# public key:' $SOPS_AGE_KEY_FILE | cut -d' ' -f4)
UNSEAL_KEYS_FILE="$BACKUP_DIR/unseal_keys.txt"
UNSEAL_KEYS_ENC="$BACKUP_DIR/unseal_keys.sops.txt"
ROOT_TOKEN_FILE="$BACKUP_DIR/root_token.txt"
ROOT_TOKEN_ENC="$BACKUP_DIR/root_token.sops.txt"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

echo "Initializing and unsealing Vault..."

# Wait for a Vault pod in phase=Running and pick the first one
echo "Waiting for a Vault pod in phase=Running..."
until POD_NAME=$(
  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=vault \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' \
  | head -n1
) && [ -n "$POD_NAME" ]; do
  echo "No Running pod found yet. Retrying in 5s..."
  sleep 5
done
echo "Vault pod in Running state: $POD_NAME"


# Initialize Vault
echo "Initializing Vault..."
INIT_OUTPUT=$(kubectl exec -n $NAMESPACE $POD_NAME -- vault operator init -format=json)
if [ $? -ne 0 ]; then
    echo "Error: Failed to initialize Vault."
    exit 1
fi
echo "Vault initialized."

# Extract unseal keys and root token
UNSEAL_KEYS=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

# Save unseal keys and root token to files
echo "Saving unseal keys and root token to files..."
echo "$UNSEAL_KEYS" > $UNSEAL_KEYS_FILE
echo "$ROOT_TOKEN" > $ROOT_TOKEN_FILE

# Encrypt files with sops using Age public key
echo "Encrypting backup files with sops..."
if ! sops --config .sops.yaml --encrypt --age $AGE_PUBLIC_KEY $UNSEAL_KEYS_FILE > "$UNSEAL_KEYS_ENC" || \
   ! sops --config .sops.yaml --encrypt --age $AGE_PUBLIC_KEY $ROOT_TOKEN_FILE > "$ROOT_TOKEN_ENC"; then
    echo "Error: Failed to encrypt files"
    rm -f $UNSEAL_KEYS_FILE $ROOT_TOKEN_FILE  # Clean up even on failure
    exit 1
fi

# Remove plaintext files and verify removal
echo "Removing plaintext files..."
rm -f $UNSEAL_KEYS_FILE $ROOT_TOKEN_FILE
if [ -f "$UNSEAL_KEYS_FILE" ] || [ -f "$ROOT_TOKEN_FILE" ]; then
    echo "Warning: Failed to remove some plaintext files"
else
    echo "Plaintext files removed successfully"
fi
echo "Encrypted files saved as: $UNSEAL_KEYS_ENC and $ROOT_TOKEN_ENC"

# Save unseal keys and root token to Kubernetes secret
echo "Saving unseal keys and root token to a Kubernetes secret..."
kubectl create secret generic vault-init-keys \
    --namespace=$NAMESPACE \
    --from-literal=root-token=$ROOT_TOKEN \
    $(echo $UNSEAL_KEYS | awk '{for(i=1;i<=NF;i++) print "--from-literal=unseal-key-"i"="$i}') \
    --dry-run=client -o yaml | kubectl apply -f -
if [ $? -ne 0 ]; then
    echo "Error: Failed to save unseal keys and root token to Kubernetes secret."
    exit 1
fi
echo "Unseal keys and root token saved to Kubernetes secret."

# Unseal Vault
echo "Unsealing Vault on all pods..."
# Get all Running Vault pods
POD_NAMES=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=vault \
  -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}')
# Loop through each pod and each unseal key
for pod in $POD_NAMES; do
  echo "Unsealing pod: $pod"
  for KEY in $UNSEAL_KEYS; do
    kubectl exec -n $NAMESPACE $pod -- vault operator unseal $KEY
    if [ $? -ne 0 ]; then
      echo "Error: Failed to unseal Vault on pod $pod with key: $KEY"
      exit 1
    fi
    echo "Unsealed pod $pod with key $KEY"
    echo ""
  done
  echo "Unsealed pod: $pod"
  echo ""
done
echo "Vault unsealed on all pods."

echo "🔧 Enabling KV v2 at path=secret/…"
kubectl exec -n $NAMESPACE $POD_NAME -- env VAULT_TOKEN=$ROOT_TOKEN \
  vault secrets enable -version=2 -path=secret kv

echo "Vault setup complete!"