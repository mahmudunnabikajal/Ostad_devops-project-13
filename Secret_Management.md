# Secret Management - Phase 4

## Overview

Secrets are sensitive data that must not be hardcoded or committed to version control. This phase implements Kubernetes Secrets for managing database credentials, API keys, and other sensitive configuration.

## Secret Management Strategy

**Approach**: Kubernetes Secrets with migration path to advanced solutions (Sealed Secrets, Vault).

**Benefits**:

- Built-in Kubernetes integration
- Separates sensitive data from code
- Environment variable injection at runtime
- Organized in dedicated manifest files

**Options**:

- **Development**: Kubernetes Secrets (built-in)
- **Production**: Sealed Secrets or HashiCorp Vault (encrypted)

## Supported Secret Types

**Opaque** (default) - Generic key-value pairs:

- Database credentials
- API keys
- JWT secrets
- Configuration values

**kubernetes.io/dockercfg** - Docker registry authentication:

- Private container image access

**kubernetes.io/service-account-token** - Auto-generated service account tokens

**kubernetes.io/basic-auth** - Username and password pairs

**kubernetes.io/ssh-auth** - SSH authentication keys

### Type: `kubernetes.io/dockercfg`

**kubernetes.io/dockercfg** - Docker registry authentication:

- Private container image access

### Type: `kubernetes.io/service-account-token`

Service account credentials (auto-generated).

### Type: `kubernetes.io/basic-auth`

Basic authentication (username + password).

### Type: `kubernetes.io/ssh-auth`

SSH authentication keys.

---

## Secret Categories

### 1. Database Credentials

**File**: `kubernetes/secrets/db-credentials.yaml`

**Keys**:

- `username` - PostgreSQL user
- `password` - PostgreSQL password
- `database` - Database name
- `db-url` - Full connection string

**Used by**: `kubernetes/backend.yaml`, `kubernetes/postgresql.yaml`

**Rotation**: Update manifest, restart PostgreSQL and backend

### 2. API Keys & Tokens

**File**: `kubernetes/secrets/api-keys.yaml`

**Keys**:

- `jwt-secret` - JWT authentication key
- `api-key` - Third-party API keys
- `redis-password` - Redis cache password
- `redis-url` - Redis connection string

**Used by**: `kubernetes/backend.yaml`

**Rotation**: Generate new keys, update manifest, restart backend

### 3. Registry Credentials

**File**: `kubernetes/secrets/registry-credentials.yaml`

**Type**: `kubernetes.io/dockercfg`

**Keys**:

- `.dockercfg` - Docker registry authentication

**Used by**: `imagePullSecrets` in pod specifications

## Implementation Guide

**Files**:

- `kubernetes/secrets/db-credentials.yaml` - Database credentials
- `kubernetes/secrets/api-keys.yaml` - API keys and tokens
- `kubernetes/secrets/registry-credentials.yaml` - Docker authentication
- `kubernetes/secrets/kustomization.yaml` - Kustomize overlay
- `kubernetes/secrets/secrets-management.sh` - Management script
- `kubernetes/secrets/README.md` - Detailed documentation

### Creating Secrets

#### Option 1: Using Kubectl (Recommended for updates)

Create secrets using kubectl command-line tool.

For database credentials:

- Specify username, password, database name, connection URL
- See `kubernetes/secrets/db-credentials.yaml` for exact values

For API keys:

- Provide JWT secret for authentication
- Provide third-party API keys
- See `kubernetes/secrets/api-keys.yaml` for configuration

For Docker registry authentication:

- Specify Docker server, username, password, email
- See `kubernetes/secrets/registry-credentials.yaml` for format

#### Option 2: Using YAML Manifests (Current Implementation)

Apply secret manifests directly using kubectl.

Use provided YAML files in `kubernetes/secrets/` directory:

- `kubernetes/secrets/db-credentials.yaml`
- `kubernetes/secrets/api-keys.yaml`
- `kubernetes/secrets/registry-credentials.yaml`

Alternatively, use Kustomize to apply secrets with overlays:

- See `kubernetes/secrets/kustomization.yaml` for configuration

#### Option 3: Using the Management Script

Use automated script for secret management operations:

- `kubernetes/secrets/secrets-management.sh`

The script provides:

- Create all secrets from manifests
- List existing secrets
- Decode secret values (for debugging)
- Update secrets
- Delete secrets
- Verify secret usage in deployments

See `kubernetes/secrets/README.md` for script usage examples.

### Referencing Secrets in Deployments

#### Method 1: Environment Variables from Secret

Used for database credentials, API keys, and configuration values.

Set environment variables from secret keys:

- `DATABASE_URL` from `db-credentials` secret
- `JWT_SECRET` from `api-keys` secret

See deployment YAML files for implementation examples.

#### Method 2: Volume Mounts (for files)

Used for certificate files, config files, or SSH keys.

Mount secrets as files at specific paths:

- Read-only access by containers
- Applications read files directly
- More secure than environment variables

#### Method 3: Image Pull Secrets (for registry)

Used to pull private container images.

Reference secret in pod specification for private registry access.

---

## Operational Procedures

## Operational Procedures

### Listing Secrets

List all secrets in the namespace to verify they exist.

See `kubernetes/secrets/` for secret manifest files.

### Describing a Secret

View secret keys without revealing values (safe for debugging).

Shows available keys in each secret.

### Viewing Secret Contents

**Caution**: Decoded secrets appear in command history.

Use management script for safer access:

- `./kubernetes/secrets/secrets-management.sh decode <secret> <key>`

Clear shell history after viewing sensitive values.

### Creating/Updating Secrets

**Steps**:

1. Edit the YAML manifest file
2. Update Base64 encoded values
3. Apply the manifest using kubectl
4. Restart deployments to use updated secrets

**Files**:

- `kubernetes/secrets/db-credentials.yaml`
- `kubernetes/secrets/api-keys.yaml`
- `kubernetes/secrets/registry-credentials.yaml`

Or use management script:

- `./kubernetes/secrets/secrets-management.sh update <secret>`

### Rotating Secrets

**Steps**:

1. Generate new password/key
2. Update secret manifest with new Base64 encoded value
3. Apply the updated manifest
4. Restart affected services (PostgreSQL first, then backend)
5. Verify services connect successfully in logs

See `kubernetes/secrets/db-credentials.yaml` for password location.

### Deleting Secrets

Delete specific secrets or entire secret set.

Use management script:

- `./kubernetes/secrets/secrets-management.sh delete`

**Warning**: Deleting secrets is permanent. Verify apps don't need them first.

### Verifying Secret Usage

Check which pods reference specific secrets.

Use management script:

- `./kubernetes/secrets/secrets-management.sh verify`

Review deployment YAML files for secret references.

### Describing a Secret

View secret keys without revealing values (safe for debugging).

Shows available keys in each secret.

### Viewing Secret Contents

**Caution**: Decoded secrets appear in command history.

Use management script for safer access:

- `./kubernetes/secrets/secrets-management.sh decode <secret> <key>`

Clear shell history after viewing sensitive values.

### Creating/Updating Secrets

**Steps**:

1. Edit the YAML manifest file
2. Update Base64 encoded values
3. Apply the manifest using kubectl
4. Restart deployments to use updated secrets

**Files**:

- `kubernetes/secrets/db-credentials.yaml`
- `kubernetes/secrets/api-keys.yaml`
- `kubernetes/secrets/registry-credentials.yaml`

Or use management script:

- `./kubernetes/secrets/secrets-management.sh update <secret>`

#### Emergency secret update

Delete and recreate the secret:

1. Delete the existing secret from Kubernetes
2. Apply the updated secret manifest
3. Restart affected deployments to pick up changes

For example, when updating API keys:

- Update the manifest file with new values
- Apply the manifest using kubectl
- Restart the backend deployment to use new values

See `kubernetes/secrets/` for manifest files.

### Rotating Secrets

#### Procedure for Password Rotation

1. **Generate new password**:
   Use a password generator or openssl to create a strong password.

2. **Update the secret manifest**:
   - Encode the new password in Base64
   - Edit the manifest file in `kubernetes/secrets/`
   - Replace the old encoded value with the new one

3. **Apply the update**:
   Apply the updated manifest using kubectl.

4. **Restart affected services**:
   Restart PostgreSQL and backend deployments in correct order.
   PostgreSQL should restart first, then dependent services.

5. **Verify connectivity**:
   Check logs of affected services to confirm they connect successfully with new password.

See `kubernetes/secrets/db-credentials.yaml` for credential location.

### Deleting Secrets

Delete specific secrets or all secrets in namespace.

Use the management script:

- `./kubernetes/secrets/secrets-management.sh delete`

Or delete manually using kubectl on individual secret files.

**Warning**: Deleting secrets is irreversible. Ensure applications don't need them first.

### Verifying Secret Usage

Check which deployments and pods reference specific secrets.

Use the management script:

- `./kubernetes/secrets/secrets-management.sh verify`

Review deployment YAML files to see secret references:

- `kubernetes/backend.yaml` - Backend secret references
- `kubernetes/postgresql.yaml` - Database secret references

---

## Security Best Practices

### 1. Secret Storage & Access Control

Implement RBAC to restrict secret access to authorized service accounts only.

Specify which service accounts can read which secrets.

See `kubernetes/secrets/README.md` for RBAC examples.

### 2. Base64 Encoding (Not Encryption)

Base64 is encoding, NOT encryption. Anyone with file access can decode values.

**Never commit plain-text secrets to Git.**

Use encryption tools like SOPS for sensitive files stored in version control.

### 3. Git Security

Add secret files to `.gitignore`:

- `kubernetes/secrets/*.yaml`
- `.env` files
- Any unencrypted credential files

Encrypt secrets before committing to Git using:

- SOPS (Secrets Operations)
- Sealed Secrets
- HashiCorp Vault

### 4. Restricting Secret Access

Create RBAC roles to limit which pods can access which secrets.

Backend pods should only access:

- `db-credentials`
- `api-keys`

Frontend pods should only access:

- Non-sensitive configuration secrets

See `kubernetes/secrets/README.md` for RBAC role examples.

### 5. Audit Logging

Monitor and log all secret access for compliance.

Enable audit logging in your Kubernetes cluster.

Review logs regularly for unauthorized access attempts.

### 6. Environment Variable Security

Sensitive data in environment variables can be inspected in pod memory.

For highly sensitive data, mount secrets as files instead:

- Secrets mounted at `/etc/secrets` (read-only)
- Applications read from files directly
- Harder to inspect in memory than env variables

See deployment YAML files for volume mount examples.

---

## Advanced Secret Management

### Option 1: Sealed Secrets (Production Ready)

Sealed Secrets encrypts secrets using asymmetric encryption. Only the cluster can decrypt.

**Features:**

- Encrypted secrets stored in Git
- Automatic decryption by cluster
- Easy secret rotation
- Audit trail available

See Sealed Secrets official documentation for installation and usage.

### Option 2: HashiCorp Vault

Enterprise-grade secret management with dynamic secrets, policies, and audit trails.

**Features:**

- Dynamic secret generation
- Fine-grained access policies
- Comprehensive audit logging
- Automated secret rotation
- Multi-cluster support

See HashiCorp Vault documentation for setup and integration.

Vault integration files available in:

- `kubernetes/vault/` - Vault deployment manifests
- `kubernetes/external-secrets/` - External Secrets Operator manifests

### Option 3: External Secrets Operator

Synchronize secrets from external systems (Vault, AWS Secrets Manager) into Kubernetes.

**Features**:

- Single source of truth for secrets
- Automatic synchronization
- Support for multiple secret providers
- Easy secret rotation

See `kubernetes/external-secrets/` for configuration examples with SecretStore and ExternalSecret manifests.

**Advantages**:

- Centralized secret management
- Cloud-native integration
- Automatic synchronization
- Flexible backend support

---

## Troubleshooting

### Issue 1: Pods Can't Access Secrets

**Problem**: Pod fails with `error reading secret` or environment variables are empty.

**Steps:**

1. Verify secret exists in namespace
2. Check pod environment variables are set
3. Review pod YAML definition for correct secretKeyRef
4. Restart the pod to reload secrets
5. Check pod logs for error messages

See `kubernetes/backend.yaml` and `kubernetes/secrets/` for configuration examples.

### Issue 2: Secret Key Not Found

**Problem**: Pod error: `couldn't find key password in Secret`

**Steps:**

1. List all keys in the secret file
2. Verify key names match what's referenced in pod YAML
3. If key is missing, update the secret manifest
4. Apply the updated secret

See `kubernetes/secrets/db-credentials.yaml` for available keys.

### Issue 3: Secret Values Not Being Read

**Problem**: Application receives empty or incorrect values from secret.

**Steps:**

1. Verify secret is Base64 encoded correctly
2. Check that pod has permission to read the secret (RBAC)
3. Verify secret reference path in pod YAML
4. Check pod logs for decode errors
5. Restart pod after updating secret

Review `kubernetes/secrets/README.md` for secret encoding details.

### Issue 4: Secret Size Limit Exceeded

**Symptom**: Error: `Secret too large`

**Info**: Kubernetes secrets have a 1MB limit per secret object.

**Solution**:

1. Check secret size: Use `kubectl get secret api-keys -n bmi-health-tracker -o json | jq '.data | length'`
2. If too large, split into multiple secrets
3. Apply separate secret files:
   - `kubernetes/secrets/db-credentials.yaml`
   - `kubernetes/secrets/api-keys.yaml`
   - `kubernetes/secrets/registry-credentials.yaml`

### Issue 5: ImagePullBackOff with Registry Credentials

**Symptom**: Pod fails with `ImagePullBackOff`, registry authentication fails.

**Solution**:

1. Verify registry secret exists: `kubectl get secret registry-credentials -n bmi-health-tracker`
2. Check imagePullSecrets in deployment: `kubectl get deployment backend -n bmi-health-tracker -o yaml | grep -A 2 imagePullSecrets`
3. Delete old registry credentials if needed: `kubectl delete secret registry-credentials -n bmi-health-tracker`
4. Create new registry credentials with your credentials
5. Update deployments with imagePullSecrets
6. Verify pods pull the image successfully

See `kubernetes/secrets/registry-credentials.yaml` for configuration.

### Issue 6: Secrets Not Reloading After Update

**Symptom**: Pods still using old secret values after update.

**Solution**:

Note: Kubernetes doesn't automatically reload secrets. You must restart pods.

1. Restart deployment: `kubectl rollout restart deployment/backend -n bmi-health-tracker`
2. Wait for new pods: `kubectl rollout status deployment/backend -n bmi-health-tracker`
3. Verify new values are loaded: Check pod environment variables with `kubectl exec`

---

## Complete Example: Database Password Rotation

### Scenario: Rotating PostgreSQL password every 90 days

**Steps**:

1. Generate new password (save securely)
2. Encode new password in Base64
3. Update secret manifest with new password
4. Update connection string with new credentials
5. Apply the secret update
6. Restart PostgreSQL StatefulSet to recognize new password
7. Wait for PostgreSQL to be ready (check pod status)
8. Restart backend deployment
9. Wait for backend pods to be ready
10. Verify backend can connect to database

Use the script at `kubernetes/secrets/secrets-management.sh` for password rotation automation.

---

## Compliance & Audit

### Audit Trail Template

Track all secret operations:

1. Review events: `kubectl get events -n bmi-health-tracker --sort-by='.lastTimestamp' | grep -i secret`
2. Export audit logs from kube-system
3. Track git changes: `git log --oneline kubernetes/secrets/`

See `kubernetes/secrets/` for audit and compliance records.
