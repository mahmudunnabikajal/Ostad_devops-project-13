# Secret Management - Phase 4

## Overview

This document outlines the secret management strategy for the BMI Health Tracker Kubernetes deployment. Secrets are sensitive data that should never be hardcoded in container images or committed to version control. This phase implements a secure, organized approach to managing secrets in Kubernetes.

## Table of Contents

1. [Secret Management Strategy](#secret-management-strategy)
2. [Supported Secret Types](#supported-secret-types)
3. [Secret Categories](#secret-categories)
4. [Implementation Guide](#implementation-guide)
5. [Operational Procedures](#operational-procedures)
6. [Security Best Practices](#security-best-practices)
7. [Advanced Secret Management](#advanced-secret-management)
8. [Troubleshooting](#troubleshooting)

---

## Secret Management Strategy

### Overview of Approach

The Phase 4 secret management implementation uses **Kubernetes Secrets** as the primary mechanism for managing sensitive data. This approach provides:

- **Built-in Integration**: Secrets are native Kubernetes objects with first-class support
- **Decoupling**: Sensitive data is separated from application code and container images
- **Environment Injection**: Secrets are injected as environment variables at runtime
- **Organization**: Secrets are structured in dedicated manifest files
- **Scalability**: Secrets are stored in `etcd` with encryption at rest (in production)

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Application Pods (Backend, Frontend, PostgreSQL)             │
├─────────────────────────────────────────────────────────────┤
│ ↑ Secret References (valueFrom: secretKeyRef)                │
├─────────────────────────────────────────────────────────────┤
│ Kubernetes Secrets (etcd-backed, encrypted)                   │
│ ├─ db-credentials                                             │
│ ├─ api-keys                                                   │
│ ├─ redis-credentials                                          │
│ ├─ app-config                                                 │
│ └─ registry-credentials                                       │
├─────────────────────────────────────────────────────────────┤
│ YAML Manifests (./kubernetes/secrets/)                        │
│ └─ Version Controlled, Encrypted/Restricted in Git            │
└─────────────────────────────────────────────────────────────┘
```

### Comparison of Approaches

| Approach               | Pros                                        | Cons                                | Use Case                       |
| ---------------------- | ------------------------------------------- | ----------------------------------- | ------------------------------ |
| **Kubernetes Secrets** | Built-in, Simple, Native integration        | Base64 (not encrypted by default)   | Development, Small deployments |
| **Sealed Secrets**     | Encrypted, Git-friendly, Easy rotation      | Requires controller                 | Production single cluster      |
| **HashiCorp Vault**    | Highly secure, Audit logs, Dynamic secrets  | Complex setup, Operational overhead | Enterprise, Multi-cluster      |
| **Cloud Managers**     | Cloud-native, Managed service, Audit trails | Vendor lock-in, Cost                | AWS/Azure/GCP deployments      |

**Phase 4 Implementation**: We use **Kubernetes Secrets** with a migration path to **Sealed Secrets** for enhanced security.

---

## Supported Secret Types

### Type: `Opaque` (default)

Generic key-value pairs, Base64 encoded. Used for:

- Database credentials
- API keys
- JWT secrets
- Configuration values

```yaml
type: Opaque
data:
  username: Ym1pX3VzZXI= # bmi_user
  password: c3Ryb25ncGFzz= # strongpassword
```

### Type: `kubernetes.io/dockercfg`

Docker registry authentication. Used for:

- Pulling private container images
- Authenticating with Docker Hub, ECR, or private registries

```yaml
type: kubernetes.io/dockercfg
data:
  .dockercfg: eyJkb2Nrz... # Encoded Docker config
```

### Type: `kubernetes.io/service-account-token`

Service account credentials (auto-generated).

### Type: `kubernetes.io/basic-auth`

Basic authentication (username + password).

### Type: `kubernetes.io/ssh-auth`

SSH authentication keys.

---

## Secret Categories

### 1. Database Credentials (`db-credentials.yaml`)

**Location**: `kubernetes/secrets/db-credentials.yaml`

**Contains**:

- `username`: PostgreSQL user (bmi_user)
- `password`: PostgreSQL password
- `database`: Database name (bmidb)
- `db-url`: Full connection string for applications

**Referenced by**:

- `backend.yaml` (DATABASE_URL environment variable)
- `postgresql.yaml` (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB)

**Rotation Strategy**: Change password in secret, restart PostgreSQL, update backup credentials.

### 2. API Keys & Tokens (`api-keys.yaml`)

**Location**: `kubernetes/secrets/api-keys.yaml`

**Contains**:

- `jwt-secret`: JWT token signing key for authentication
- `api-key`: Third-party API integration keys
- `redis-password`: Redis cache password
- `redis-url`: Redis connection string with authentication

**Referenced by**:

- `backend.yaml` (JWT_SECRET, API_KEY environment variables)

**Rotation Strategy**: Generate new keys, update secret, restart deployments.

### 3. Application Configuration (`api-keys.yaml`)

**Location**: `kubernetes/secrets/api-keys.yaml`

**Contains**:

- `app-secret`: Application-level secret key
- `log-level`: Application logging level

**Referenced by**:

- `backend.yaml` (LOG_LEVEL environment variable)

**Use Case**: Non-critical but sensitive configuration values.

### 4. Registry Credentials (`registry-credentials.yaml`)

**Location**: `kubernetes/secrets/registry-credentials.yaml`

**Type**: `kubernetes.io/dockercfg`

**Contains**:

- `.dockercfg`: Docker registry authentication

**Usage**: Reference in `imagePullSecrets` for private image pulling:

```yaml
spec:
  imagePullSecrets:
    - name: registry-credentials
```

---

## Implementation Guide

### Directory Structure

```
kubernetes/
├── secrets/                          # Phase 4: Secret Management
│   ├── db-credentials.yaml           # Database credentials secret
│   ├── api-keys.yaml                 # API keys & tokens secret
│   ├── registry-credentials.yaml     # Docker registry credentials
│   ├── kustomization.yaml            # Kustomize overlay
│   ├── secrets-management.sh         # Secret management script
│   └── README.md                     # Secret usage documentation
├── backend.yaml                      # Updated with secret references
├── frontend.yaml                     # Frontend deployment
├── postgresql.yaml                   # Updated with secret references
├── redis.yaml                        # Redis deployment
├── ingress.yaml                      # Ingress configuration
├── namespace.yaml                    # Namespace definition
└── ... (other K8s files)
```

### Creating Secrets

#### Option 1: Using Kubectl (Recommended for updates)

```bash
# Create database credentials secret
kubectl create secret generic db-credentials \
  --from-literal=username=bmi_user \
  --from-literal=password=strongpassword \
  --from-literal=database=bmidb \
  --from-literal=db-url='postgresql://bmi_user:strongpassword@postgresql-service:5432/bmidb' \
  -n bmi-health-tracker

# Create API keys secret
kubectl create secret generic api-keys \
  --from-literal=jwt-secret='your-super-secret-jwt-key' \
  --from-literal=api-key='your-api-key' \
  -n bmi-health-tracker

# Create Docker registry secret
kubectl create secret docker-registry registry-credentials \
  --docker-server=docker.io \
  --docker-username=mahmudunnabikajal \
  --docker-password=<your-token> \
  --docker-email=your-email@example.com \
  -n bmi-health-tracker
```

#### Option 2: Using YAML Manifests (Current Implementation)

```bash
# Apply all secrets using manifests
kubectl apply -f kubernetes/secrets/

# Or use Kustomize
kubectl apply -k kubernetes/secrets/
```

#### Option 3: Using the Management Script

```bash
# Make script executable
chmod +x kubernetes/secrets/secrets-management.sh

# Create all secrets
./kubernetes/secrets/secrets-management.sh create

# Verify creation
./kubernetes/secrets/secrets-management.sh list
```

### Referencing Secrets in Deployments

#### Method 1: Environment Variables from Secret

Used for database credentials, API keys, and configuration values.

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: db-url
  - name: JWT_SECRET
    valueFrom:
      secretKeyRef:
        name: api-keys
        key: jwt-secret
```

#### Method 2: Volume Mounts (for files)

Used for certificate files, config files, or SSH keys.

```yaml
volumes:
  - name: secret-volume
    secret:
      secretName: my-secret
containers:
  - name: app
    volumeMounts:
      - name: secret-volume
        mountPath: /etc/secrets
        readOnly: true
```

#### Method 3: Image Pull Secrets (for registry)

Used to pull private container images.

```yaml
spec:
  imagePullSecrets:
    - name: registry-credentials
```

---

## Operational Procedures

### Listing All Secrets

```bash
# List secrets in the namespace
kubectl get secrets -n bmi-health-tracker

# List with more details
kubectl get secrets -n bmi-health-tracker -o wide

# List with labels
kubectl get secrets -n bmi-health-tracker -L app,component
```

### Describing a Secret

```bash
# Describe a specific secret (shows keys, not values)
kubectl describe secret db-credentials -n bmi-health-tracker

# Output shows all keys but hides sensitive values for safety
```

### Viewing Secret Contents (Caution ⚠️)

```bash
# Decode and display a secret value (use with caution)
kubectl get secret db-credentials -n bmi-health-tracker \
  -o jsonpath='{.data.password}' | base64 -d

# Using the management script
./kubernetes/secrets/secrets-management.sh decode db-credentials password
```

⚠️ **Warning**: Decoded secrets are visible in command history. Use this only when necessary and clear history afterward.

### Creating/Updating Secrets

#### Update from YAML manifest

```bash
# Edit the YAML file
nano kubernetes/secrets/api-keys.yaml

# Update Base64 encoded values:
echo -n 'new-password' | base64

# Apply the updated manifest
kubectl apply -f kubernetes/secrets/api-keys.yaml

# Restart deployments to pick up changes
kubectl rollout restart deployment/backend -n bmi-health-tracker
```

#### Update using the management script

```bash
# Update a specific secret
./kubernetes/secrets/secrets-management.sh update api-keys

# The script will delete and re-create the secret from the manifest
```

#### Emergency secret update

```bash
# Delete and recreate
kubectl delete secret api-keys -n bmi-health-tracker
kubectl apply -f kubernetes/secrets/api-keys.yaml

# Restart affected pods
kubectl rollout restart deployment/backend -n bmi-health-tracker
```

### Rotating Secrets

#### Procedure for Password Rotation

1. **Generate new password**:

   ```bash
   openssl rand -base64 32
   # Output: abc123XYZ...
   ```

2. **Update the secret manifest**:

   ```bash
   # Encode the new password
   echo -n 'abc123XYZ...' | base64
   # Output: YWJjMTIzWFlausD...

   # Edit the manifest
   nano kubernetes/secrets/db-credentials.yaml
   # Replace: password: c3Ryb25ncGFzc3dvcmQ=
   # With:    password: YWJjMTIzWFlausD...
   ```

3. **Apply the update**:

   ```bash
   kubectl apply -f kubernetes/secrets/db-credentials.yaml
   ```

4. **Restart affected services**:

   ```bash
   # Restart PostgreSQL first
   kubectl rollout restart statefulset/postgresql -n bmi-health-tracker

   # Restart backend
   kubectl rollout restart deployment/backend -n bmi-health-tracker
   ```

5. **Verify connectivity**:
   ```bash
   # Check backend logs for successful connection
   kubectl logs -f deployment/backend -n bmi-health-tracker
   ```

### Deleting Secrets

```bash
# Delete a specific secret
kubectl delete secret api-keys -n bmi-health-tracker

# Delete all secrets (careful!)
kubectl delete secrets --all -n bmi-health-tracker

# Using the management script
./kubernetes/secrets/secrets-management.sh delete
```

### Verifying Secret Usage

```bash
# Check how secrets are referenced in deployments
./kubernetes/secrets/secrets-management.sh verify

# Alternatively, view the deployment YAML
kubectl get deployment backend -n bmi-health-tracker -o yaml | grep -A 10 secretKeyRef

# List all pods using a specific secret
kubectl get pods -n bmi-health-tracker -o jsonpath=\
  '{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].env[*].valueFrom.secretKeyRef.name}{"\n"}{end}'
```

---

## Security Best Practices

### 1. Secret Storage & Access Control

```bash
# Create RBAC role for secret access
kubectl create role secrets-reader \
  --verb=get,list \
  --resource=secrets \
  -n bmi-health-tracker

# Bind role to service account
kubectl create rolebinding secrets-reader \
  --role=secrets-reader \
  --serviceaccount=bmi-health-tracker:default \
  -n bmi-health-tracker
```

### 2. Base64 Encoding (Not Encryption)

⚠️ **Important**: Base64 is encoding, NOT encryption. Anyone with access to the YAML files can decode the secrets:

```bash
# To decode (easy!)
echo 'c3Ryb25ncGFzc3dvcmQ=' | base64 -d
# Output: strongpassword
```

**Never commit plain-text secrets to Git. For Git storage, use encryption**.

### 3. Git Security

```bash
# Create .gitignore patterns
echo "kubernetes/secrets/*.yaml" >> .gitignore
echo ".env" >> .gitignore

# Or encrypt secrets before committing
kubectl create secret generic db-credentials \
  --from-literal=username=bmi_user \
  --dry-run=client -o yaml | sops -e - > kubernetes/secrets/db-credentials-encrypted.yaml
```

### 4. Restricting Secret Access

```yaml
# RBAC: Only let backend pods read db-credentials
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-secrets
  namespace: bmi-health-tracker
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["db-credentials", "api-keys"] # Only these secrets
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-secrets
  namespace: bmi-health-tracker
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: backend-secrets
subjects:
  - kind: ServiceAccount
    name: backend
    namespace: bmi-health-tracker
```

### 5. Audit Logging

Enable audit logs to track secret access:

```bash
# Check audit logs (if enabled in cluster)
kubectl get events -n bmi-health-tracker | grep secret

# Watch for secret access
kubectl logs -f -n kube-system -l component=audit-webhook
```

### 6. Environment Variable Security

Avoid storing highly sensitive data as environment variables. For maximum security:

```yaml
# Instead of env variables, mount as files (harder to inspect in memory)
volumeMounts:
  - name: db-secret
    mountPath: /etc/db-credentials
    readOnly: true
volumes:
  - name: db-secret
    secret:
      secretName: db-credentials
```

---

## Advanced Secret Management

### Option 1: Sealed Secrets (Production Ready)

Sealed Secrets encrypts secrets using asymmetric encryption. Only the cluster can decrypt them.

#### Installation

```bash
# Add Sealed Secrets Helm repo
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Verify installation
kubectl get deployment sealed-secrets -n kube-system
```

#### Usage

```bash
# Create a secret and seal it
echo -n 'strongpassword' | kubectl create secret generic db-password \
  --dry-run=client \
  --from-file=/dev/stdin \
  -o yaml | kubeseal -f - > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml

# Sealed secret auto-decrypts when applied to the cluster
```

**Advantages**:

- Encrypted at rest in Git
- Only the cluster can decrypt
- Easy secret rotation
- Audit trail available

### Option 2: HashiCorp Vault

For enterprise deployments with dynamic secrets, policies, and audit trails.

#### Installation

```bash
# Add Vault Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace

# Unseal Vault
kubectl exec -it vault-0 -n vault -- vault operator init
kubectl exec -it vault-0 -n vault -- vault operator unseal

# Configure Kubernetes auth
kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
```

#### Integration with Kubernetes

```yaml
# Pod with Vault annotation
apiVersion: v1
kind: Pod
metadata:
  name: app
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-db: "secret/data/db"
spec:
  containers:
    - name: app
      image: myapp:latest
```

**Advantages**:

- Dynamic secrets generation
- Fine-grained access policies
- Audit logging
- Secret rotation automation
- Multi-cluster support

### Option 3: External Secrets (Hybrid Approach)

External Secrets allows synchronizing secrets from external systems (Vault, AWS Secrets Manager, etc.) into Kubernetes.

#### Installation

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

#### Configuration

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault.svc"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: db-password
```

**Advantages**:

- Centralized secret management
- Cloud-native integration
- Automatic synchronization
- Flexible backend support

---

## Troubleshooting

### Issue 1: Pods Can't Access Secrets

**Symptom**: Pod fails with `error reading secret` or environment variables are empty.

**Solution**:

```bash
# Check if secret exists
kubectl get secrets db-credentials -n bmi-health-tracker

# Check pod environment variables
kubectl exec -it pod/backend-xxxxx -c backend \
  -n bmi-health-tracker -- env | grep DATABASE

# Check pod definition
kubectl get pod backend-xxxxx -n bmi-health-tracker -o yaml | grep -A 5 secretKeyRef

# Restart the pod to reload secrets
kubectl rollout restart deployment/backend -n bmi-health-tracker
```

### Issue 2: Secret Key Not Found

**Symptom**: Pod error: `couldn't find key password in Secret default/my-secret`

**Solution**:

```bash
# List all keys in the secret
kubectl get secret db-credentials -n bmi-health-tracker -o jsonpath='{.data}' | jq keys

# Expected output:
# ["database", "db-url", "password", "username"]

# If key is missing, update the secret
kubectl apply -f kubernetes/secrets/db-credentials.yaml
```

### Issue 3: Base64 Decoding Issues

**Symptom**: Application receives garbled text from secret.

**Solution**:

```bash
# Verify the encoded value is correct
echo -n 'strongpassword' | base64
# Output: c3Ryb25ncGFzc3dvcmQ=

# If different, update the secret with correct encoding
nano kubernetes/secrets/db-credentials.yaml

# Apply the fix
kubectl apply -f kubernetes/secrets/db-credentials.yaml
```

### Issue 4: Secret Size Limit Exceeded

**Symptom**: Error: `Secret too large`

**Info**: Kubernetes secrets have a 1MB limit per secret object.

**Solution**:

```bash
# Check secret size
kubectl get secret api-keys -n bmi-health-tracker -o json | jq '.data | length'

# If too large, split into multiple secrets
# Create separate secrets for different components
kubectl apply -f kubernetes/secrets/db-credentials.yaml
kubectl apply -f kubernetes/secrets/api-keys.yaml
kubectl apply -f kubernetes/secrets/registry-credentials.yaml
```

### Issue 5: ImagePullBackOff with Registry Credentials

**Symptom**: Pod fails with `ImagePullBackOff`, registry authentication fails.

**Solution**:

```bash
# Verify registry secret exists
kubectl get secret registry-credentials -n bmi-health-tracker

# Check imagePullSecrets in deployment
kubectl get deployment backend -n bmi-health-tracker -o yaml | grep -A 2 imagePullSecrets

# Recreate registry credentials
kubectl delete secret registry-credentials -n bmi-health-tracker
kubectl create secret docker-registry registry-credentials \
  --docker-server=docker.io \
  --docker-username=<your-username> \
  --docker-password=<your-token> \
  --docker-email=<your-email> \
  -n bmi-health-tracker

# Update deployments to use the secret
kubectl patch deployment backend -n bmi-health-tracker -p \
  '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"registry-credentials"}]}}}}'
```

### Issue 6: Secrets Not Reloading After Update

**Symptom**: Pods still using old secret values after update.

**Solution**:

```bash
# Kubernetes doesn't automatically reload secrets
# You must restart the pods

# Restart deployment
kubectl rollout restart deployment/backend -n bmi-health-tracker

# Wait for new pods to be ready
kubectl rollout status deployment/backend -n bmi-health-tracker

# Verify new values are loaded
kubectl exec -it deployment/backend -n bmi-health-tracker -- env | grep DATABASE_URL
```

---

## Complete Example: Database Password Rotation

### Scenario: Rotating PostgreSQL password every 90 days

```bash
#!/bin/bash
# rotate-db-password.sh

NAMESPACE="bmi-health-tracker"
OLD_PASSWORD="strongpassword"
NEW_PASSWORD=$(openssl rand -base64 32)

echo "Rotating database password..."
echo "New password (save securely): $NEW_PASSWORD"

# Step 1: Encode new password
ENCODED_PASSWORD=$(echo -n "$NEW_PASSWORD" | base64)

# Step 2: Update secret manifest
sed -i "s/password: .*/password: $ENCODED_PASSWORD/" \
  kubernetes/secrets/db-credentials.yaml

# Step 3: Update connection string
NEW_DB_URL="postgresql://bmi_user:${NEW_PASSWORD}@postgresql-service:5432/bmidb"
ENCODED_URL=$(echo -n "$NEW_DB_URL" | base64)
sed -i "s/db-url: .*/db-url: $ENCODED_URL/" \
  kubernetes/secrets/db-credentials.yaml

# Step 4: Apply the secret update
kubectl apply -f kubernetes/secrets/db-credentials.yaml
echo "✓ Secret updated"

# Step 5: Restart PostgreSQL
kubectl rollout restart statefulset/postgresql -n $NAMESPACE
echo "✓ PostgreSQL restarting..."

# Wait for PostgreSQL to be ready
kubectl rollout status statefulset/postgresql -n $NAMESPACE --timeout=5m

# Step 6: Restart backend
kubectl rollout restart deployment/backend -n $NAMESPACE
echo "✓ Backend restarting..."

# Wait for backend to be ready
kubectl rollout status deployment/backend -n $NAMESPACE --timeout=5m

# Step 7: Verify
echo "✓ Password rotation complete"
echo "Verifying backend connectivity..."
kubectl logs -f deployment/backend -n $NAMESPACE | grep -i "connected\|error" | head -5

echo "Done!"
```

---

## Compliance & Audit

### Audit Trail Template

```bash
# Log all secret operations
kubectl get events -n bmi-health-tracker --sort-by='.lastTimestamp' | grep -i secret

# Export audit log
kubectl logs -n kube-system -l component=audit-webhook > secret-audit.log

# Track changes
git log --oneline kubernetes/secrets/
```
