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
echo "kubectl exec -n $NAMESPACE $POD_NAME -- vault operator init -format=json"
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

# Enable and Configure Kubernetes Auth
echo "🔧 Enabling Kubernetes auth method in Vault..."
kubectl exec -n $NAMESPACE $POD_NAME -- env VAULT_TOKEN=$ROOT_TOKEN \\
  vault auth enable kubernetes
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable Kubernetes auth method in Vault."
    # Attempt to clean up encrypted files if auth enabling fails, to prevent leaving system in intermediate state
    sops -d "$UNSEAL_KEYS_ENC" > /dev/null 2>&1 && rm -f "$UNSEAL_KEYS_ENC"
    sops -d "$ROOT_TOKEN_ENC" > /dev/null 2>&1 && rm -f "$ROOT_TOKEN_ENC"
    exit 1
fi
echo "✅ Kubernetes auth method enabled."

echo "⚙️ Configuring Kubernetes auth method..."
# Discover Kubernetes API host and port from within the pod
K8S_HOST=$(kubectl exec -n $NAMESPACE $POD_NAME -- printenv KUBERNETES_SERVICE_HOST)
K8S_PORT=$(kubectl exec -n $NAMESPACE $POD_NAME -- printenv KUBERNETES_SERVICE_PORT)

kubectl exec -n $NAMESPACE $POD_NAME -- env VAULT_TOKEN=$ROOT_TOKEN \\
  vault write auth/kubernetes/config \\
  kubernetes_host="https://$K8S_HOST:$K8S_PORT" \\
  # Optionally, add token_reviewer_jwt, kubernetes_ca_cert, etc. if needed for your setup
  # token_reviewer_jwt=\"$(kubectl exec -n $NAMESPACE $POD_NAME -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \\
  # kubernetes_ca_cert=\"$(kubectl exec -n $NAMESPACE $POD_NAME -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)\"
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure Kubernetes auth method in Vault."
    # Attempt to clean up
    sops -d "$UNSEAL_KEYS_ENC" > /dev/null 2>&1 && rm -f "$UNSEAL_KEYS_ENC"
    sops -d "$ROOT_TOKEN_ENC" > /dev/null 2>&1 && rm -f "$ROOT_TOKEN_ENC"
    exit 1
fi
echo "✅ Kubernetes auth method configured."

# Save unseal keys and root token to Kubernetes secret
# This secret stores the *initial* root token, which we are about to revoke.
# Unseal keys remain critical.
echo "Saving unseal keys and initial root token to a Kubernetes secret (vault-init-keys)..."
kubectl create secret generic vault-init-keys -n $NAMESPACE \
  --from-literal=VAULT_ROOT_TOKEN="$ROOT_TOKEN" \
  --from-file=VAULT_UNSEAL_KEYS_B64=$UNSEAL_KEYS_ENC \
  --dry-run=client -o yaml | kubectl apply -f -

if [ $? -ne 0 ]; then
    echo "Error: Failed to save unseal keys and root token to Kubernetes secret."
    # Attempt to clean up
    sops -d "$UNSEAL_KEYS_ENC" > /dev/null 2>&1 && rm -f "$UNSEAL_KEYS_ENC"
    sops -d "$ROOT_TOKEN_ENC" > /dev/null 2>&1 && rm -f "$ROOT_TOKEN_ENC"
    exit 1
fi
echo "✅ Unseal keys and initial root token saved to Kubernetes secret."

# Also save unseal keys in plain text format for auto-unseal init container
# (Still protected by Kubernetes RBAC and encryption at rest)
echo "Saving unseal keys in plain text format for auto-unseal..."
echo "$UNSEAL_KEYS" > /tmp/unseal-keys-plain.txt
kubectl create secret generic vault-unseal-keys -n $NAMESPACE \
  --from-file=unseal-keys=/tmp/unseal-keys-plain.txt \
  --dry-run=client -o yaml | kubectl apply -f -
rm -f /tmp/unseal-keys-plain.txt

if [ $? -ne 0 ]; then
    echo "Warning: Failed to save plain text unseal keys for auto-unseal."
else
    echo "✅ Plain text unseal keys saved for auto-unseal."
fi


# Revoke the initial root token
echo "🔒 Revoking the initial root token..."
kubectl exec -n $NAMESPACE $POD_NAME -- env VAULT_TOKEN=$ROOT_TOKEN \\
  vault token revoke -self
if [ $? -ne 0 ]; then
    echo "Warning: Failed to revoke the initial root token. Please revoke it manually."
    # This is a warning because the primary setup might be complete, but security is compromised.
else
    echo "✅ Initial root token revoked successfully."
fi

echo "Vault initialization, unsealing, Kubernetes auth setup, and root token revocation complete."
echo "Encrypted unseal keys are stored in $UNSEAL_KEYS_ENC"
echo "The initial root token (now revoked) was stored in $ROOT_TOKEN_ENC and in the 'vault-init-keys' Kubernetes secret."
echo "Future operations should rely on the configured Kubernetes auth method or other non-root tokens/auth methods."

exit 0 # Ensure script exits cleanly if all went well