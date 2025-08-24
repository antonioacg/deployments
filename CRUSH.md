# CRUSH Development Guidelines

## Build/Lint/Test Commands

```bash
# Install dependencies
./install.sh

# Verify installation
flux get all --all-namespaces

# Check Flux status
flux get all

# Check pod status
kubectl get pods -A

# Test SOPS encryption (example)
echo "secret: test" | sops --encrypt --age $(grep "^# public key:" $SOPS_AGE_KEY_FILE | cut -d' ' -f4) /dev/stdin
```

## Code Style Guidelines

### File Structure
- Use YAML for Kubernetes manifests
- Organize by component/namespace
- Use kustomization.yaml for Kustomize-based deployments

### Naming Conventions
- Use lowercase with hyphens for file names
- Use descriptive names for resources
- Follow Kubernetes naming conventions

### Formatting
- Use 2-space indentation
- No trailing whitespace
- End files with a newline
- Array items should be hyphenated with a space after

### Imports and References
- Use relative paths for local references
- Reference external repositories through proper Flux sources
- Keep image tags specific (no latest unless absolutely necessary)

### Types
- Use proper Kubernetes API versions
- Match resource kinds to their corresponding API groups
- Use appropriate string/integer types for fields

### Error Handling
- Use proper Kubernetes health checks (liveness/readiness probes)
- Include appropriate resource limits and requests
- Use proper error handling in shell scripts with `set -e`

## Kubernetes-Specific Guidelines

### Manifest Structure
- apiVersion, kind, metadata, spec (in that order)
- Include namespace in metadata when appropriate
- Use labels for organization and selection

### Secrets Management
- Encrypt secrets using SOPS with Age
- Never commit unencrypted secrets
- Use sealed secrets or similar for GitOps workflows

### Kustomize
- Use strategic merge patches for modifications
- Keep base configurations generic
- Override values in overlays

## Special Directories
- clusters/: Cluster-specific configurations
- namespaces/: Namespace definitions
- apps/: Application deployments
- pvc/: Persistent volume claims

## Important Files
- .sops.yaml: SOPS configuration
- install.sh: Main installation script
- install-sops-age.sh: SOPS/Age installation