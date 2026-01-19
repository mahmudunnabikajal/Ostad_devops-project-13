#!/bin/bash

# Vault Setup and Configuration Script
# This script initializes and configures HashiCorp Vault for the BMI Health Tracker

set -e

VAULT_NAMESPACE="vault"
BMI_NAMESPACE="bmi-health-tracker"
VAULT_POD="vault-0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Step 1: Check if Vault pod is running
echo ""
echo "=========================================="
echo "Step 1: Checking Vault Pod Status"
echo "=========================================="

if kubectl get pod $VAULT_POD -n $VAULT_NAMESPACE &>/dev/null; then
    print_success "Vault pod is running"
else
    print_error "Vault pod is not found. Please deploy Vault first."
    echo "Run: kubectl apply -f kubernetes/vault/"
    exit 1
fi

# Step 2: Check if Vault is initialized
echo ""
echo "=========================================="
echo "Step 2: Checking Vault Initialization"
echo "=========================================="

VAULT_STATUS=$(kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- vault status 2>/dev/null || echo "Error")

if echo "$VAULT_STATUS" | grep -q "Initialized.*true" || echo "$VAULT_STATUS" | grep -q "initialized: true"; then
    print_success "Vault is already initialized"
else
    print_warning "Vault is not initialized. Initializing now..."
    
    # Initialize Vault and capture output
    INIT_OUTPUT=$(kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json 2>/dev/null || true)
    
    # Extract unseal key and root token
    UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.keys_base64[0]')
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    
    # Save to file (important!)
    cat > /tmp/vault-init.json << EOF
$INIT_OUTPUT
EOF
    
    print_success "Vault initialized"
    print_info "Unseal Key: $UNSEAL_KEY"
    print_info "Root Token: $ROOT_TOKEN"
    print_warning "Vault init credentials saved to /tmp/vault-init.json - KEEP THIS SAFE!"
fi

# Step 3: Unseal Vault
echo ""
echo "=========================================="
echo "Step 3: Unsealing Vault"
echo "=========================================="

SEALED_STATUS=$(kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- vault status 2>/dev/null | grep "Sealed" || echo "Sealed.*true")

if echo "$SEALED_STATUS" | grep -q "true"; then
    print_warning "Vault is sealed. Unsealing..."
    
    # Try to get unseal key from previous init output
    if [ -f /tmp/vault-init.json ]; then
        UNSEAL_KEY=$(jq -r '.keys_base64[0]' /tmp/vault-init.json)
        print_info "Using unseal key from /tmp/vault-init.json"
    else
        print_error "Cannot find unseal key. Please provide it:"
        read -p "Enter unseal key: " UNSEAL_KEY
    fi
    
    kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- vault operator unseal "$UNSEAL_KEY" > /dev/null 2>&1 || true
    sleep 2
    print_success "Vault unsealed"
else
    print_success "Vault is already unsealed"
fi

# Step 4: Get root token and login
echo ""
echo "=========================================="
echo "Step 4: Setting up Vault Authentication"
echo "=========================================="

if [ -f /tmp/vault-init.json ]; then
    ROOT_TOKEN=$(jq -r '.root_token' /tmp/vault-init.json)
    print_info "Using root token from init file"
else
    print_warning "Root token file not found. Please provide it:"
    read -p "Enter root token: " ROOT_TOKEN
fi

# Login to Vault
kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN vault auth list > /dev/null 2>&1 && echo ok || echo notok" > /dev/null 2>&1

print_success "Vault authentication set"

# Step 5: Enable KV Secrets Engine
echo ""
echo "=========================================="
echo "Step 5: Enabling Secrets Engine"
echo "=========================================="

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN vault secrets enable -version=2 -path=secret kv || echo 'KV already enabled'" > /dev/null 2>&1

print_success "KV Secrets Engine v2 enabled at path /secret"

# Step 6: Create secrets for BMI Health Tracker
echo ""
echo "=========================================="
echo "Step 6: Creating Application Secrets"
echo "=========================================="

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault kv put secret/bmi-health-tracker/database \
    username=bmi_user \
    password=strongpassword \
    database=bmidb \
    host=postgresql-service \
    port=5432 \
    connection_string='postgresql://bmi_user:strongpassword@postgresql-service:5432/bmidb'" > /dev/null 2>&1

print_success "Database secret created at secret/bmi-health-tracker/database"

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault kv put secret/bmi-health-tracker/api \
    jwt_secret='your-super-secret-jwt-key-change-in-production' \
    api_key='3kkd9s0L2mP8qR4xJ7vN1wM5yZ5bC9' \
    log_level='info'" > /dev/null 2>&1

print_success "API secret created at secret/bmi-health-tracker/api"

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault kv put secret/bmi-health-tracker/cache \
    redis_password='redis-secure-password-123' \
    redis_host=redis-service \
    redis_port=6379 \
    redis_url='redis://:redis-secure-password-123@redis-service:6379'" > /dev/null 2>&1

print_success "Cache secret created at secret/bmi-health-tracker/cache"

# Step 7: Enable Kubernetes Auth Method
echo ""
echo "=========================================="
echo "Step 7: Enabling Kubernetes Auth Method"
echo "=========================================="

KUBE_HOST=$(kubectl cluster-info | grep 'Kubernetes master' | awk '/https/ {print $NF}' || echo "https://kubernetes.default.svc.cluster.local:443")
KUBE_CA=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)
KUBE_TOKEN=$(kubectl get secret $(kubectl get secret -n $VAULT_NAMESPACE -o name -l 'app=vault' 2>/dev/null | head -1) -n $VAULT_NAMESPACE -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")

# If KUBE_TOKEN is empty, try alternative method
if [ -z "$KUBE_TOKEN" ]; then
    KUBE_TOKEN=$(kubectl get serviceaccount vault -n $VAULT_NAMESPACE -o jsonpath='{.secrets[0].name}' | xargs -I {} kubectl get secret {} -n $VAULT_NAMESPACE -o jsonpath='{.data.token}' | base64 -d)
fi

print_info "Kubernetes API: $KUBE_HOST"

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault auth enable kubernetes" > /dev/null 2>&1 || print_warning "Kubernetes auth already enabled"

print_success "Kubernetes auth method enabled"

# Step 8: Configure Kubernetes Auth
echo ""
echo "=========================================="
echo "Step 8: Configuring Kubernetes Auth"
echo "=========================================="

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault write auth/kubernetes/config \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
    kubernetes_host=https://\$KUBERNETES_SERVICE_HOST:\$KUBERNETES_SERVICE_PORT \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt" > /dev/null 2>&1

print_success "Kubernetes auth configured"

# Step 9: Create Vault Role for Backend
echo ""
echo "=========================================="
echo "Step 9: Creating Vault Roles"
echo "=========================================="

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault write auth/kubernetes/role/bmi-backend \
    bound_service_account_names=default \
    bound_service_account_namespaces=$BMI_NAMESPACE \
    policies=bmi-backend \
    ttl=24h" > /dev/null 2>&1

print_success "Vault role 'bmi-backend' created"

# Step 10: Create Policy for Backend
echo ""
echo "=========================================="
echo "Step 10: Creating Vault Policies"
echo "=========================================="

kubectl exec -it $VAULT_POD -n $VAULT_NAMESPACE -- \
    sh -c "VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=$ROOT_TOKEN \
    vault policy write bmi-backend - << 'POLICY'
path \"secret/data/bmi-health-tracker/*\" {
  capabilities = [\"read\", \"list\"]
}
path \"secret/metadata/bmi-health-tracker/*\" {
  capabilities = [\"read\", \"list\"]
}
POLICY" > /dev/null 2>&1

print_success "Vault policy 'bmi-backend' created"

# Step 11: Display Summary
echo ""
echo "=========================================="
echo "✅ Vault Setup Complete!"
echo "=========================================="
echo ""
print_info "Vault is now configured and ready to use"
echo ""
print_info "Next steps:"
echo "  1. Deploy External Secrets Operator: kubectl apply -f kubernetes/external-secrets/"
echo "  2. Update deployments to use Vault secrets"
echo "  3. Configure pod authentication with Vault"
echo ""
print_warning "Important: Save your Vault initialization details:"
echo "  - Unseal Key: $UNSEAL_KEY (from /tmp/vault-init.json)"
echo "  - Root Token: $ROOT_TOKEN (from /tmp/vault-init.json)"
echo ""
print_info "Vault UI: kubectl port-forward svc/vault-ui -n $VAULT_NAMESPACE 8200:8200"
echo ""

# Store credentials in a secure location
cat > /tmp/vault-credentials.txt << EOF
Vault Setup Credentials
=======================
Root Token: $ROOT_TOKEN
Unseal Key: $UNSEAL_KEY
Kubernetes Auth Enabled: Yes
Secrets Path: secret/bmi-health-tracker/

Secrets Created:
  - secret/bmi-health-tracker/database
  - secret/bmi-health-tracker/api
  - secret/bmi-health-tracker/cache

Keep this file secure!
EOF

print_warning "Credentials saved to /tmp/vault-credentials.txt"
