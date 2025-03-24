# No-IP DUC Setup

## Managing Secrets

Since we're using FluxCD, we need to create the secret directly in the cluster before Flux syncs:

```bash
# Set your No-IP credentials
export NOIP_USERNAME="your-username"
export NOIP_PASSWORD="your-password"

# Create the secret in the cluster
kubectl create secret generic noip-credentials \
  --namespace no-ip \
  --from-literal=username=$NOIP_USERNAME \
  --from-literal=password=$NOIP_PASSWORD
```

The deployment will reference this secret via the secretKeyRef configuration.

Note: Do not commit real credentials to the repository. The secret.yaml file in this directory serves as a template and reference for the expected secret structure.
