#!/bin/bash

# Secret Management Script for Kubernetes
# This script helps manage secrets in the BMI Health Tracker application

set -e

NAMESPACE="bmi-health-tracker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to create secrets
create_secrets() {
    echo "Creating Kubernetes secrets..."
    
    # Apply all secret manifests
    kubectl apply -f "$SCRIPT_DIR/db-credentials.yaml"
    kubectl apply -f "$SCRIPT_DIR/api-keys.yaml"
    kubectl apply -f "$SCRIPT_DIR/registry-credentials.yaml"
    
    print_success "All secrets created successfully"
}

# Function to list secrets
list_secrets() {
    echo "Secrets in namespace: $NAMESPACE"
    kubectl get secrets -n "$NAMESPACE" -o wide
}

# Function to describe a specific secret
describe_secret() {
    local secret_name=$1
    if [ -z "$secret_name" ]; then
        print_error "Please provide secret name"
        exit 1
    fi
    
    echo "Describing secret: $secret_name"
    kubectl describe secret "$secret_name" -n "$NAMESPACE"
}

# Function to decode a secret value
decode_secret() {
    local secret_name=$1
    local key=$2
    
    if [ -z "$secret_name" ] || [ -z "$key" ]; then
        print_error "Usage: decode_secret <secret-name> <key>"
        exit 1
    fi
    
    echo "Decoding secret: $secret_name / $key"
    kubectl get secret "$secret_name" -n "$NAMESPACE" -o jsonpath="{.data.$key}" | base64 -d
    echo ""
}

# Function to update a secret
update_secret() {
    local secret_name=$1
    
    if [ -z "$secret_name" ]; then
        print_error "Please provide secret name"
        exit 1
    fi
    
    echo "Updating secret: $secret_name"
    kubectl delete secret "$secret_name" -n "$NAMESPACE" --ignore-not-found
    
    # Re-apply the corresponding manifest
    case "$secret_name" in
        db-credentials)
            kubectl apply -f "$SCRIPT_DIR/db-credentials.yaml"
            print_success "Updated db-credentials secret"
            ;;
        api-keys)
            kubectl apply -f "$SCRIPT_DIR/api-keys.yaml"
            print_success "Updated api-keys secret"
            ;;
        registry-credentials)
            kubectl apply -f "$SCRIPT_DIR/registry-credentials.yaml"
            print_success "Updated registry-credentials secret"
            ;;
        *)
            print_error "Unknown secret: $secret_name"
            exit 1
            ;;
    esac
}

# Function to delete secrets
delete_secrets() {
    echo "Deleting all secrets..."
    kubectl delete secret db-credentials api-keys registry-credentials \
        -n "$NAMESPACE" --ignore-not-found
    print_success "All secrets deleted"
}

# Function to rotate secrets
rotate_secrets() {
    print_warning "Secret rotation requires manual updates to the secret manifests"
    print_warning "Follow these steps:"
    echo "1. Edit the secret manifest files in kubernetes/secrets/"
    echo "2. Update Base64-encoded values (use: echo -n 'value' | base64)"
    echo "3. Apply the updated manifests using: ./secrets-management.sh update <secret-name>"
    echo "4. Restart deployments to pick up new secrets:"
    echo "   kubectl rollout restart deployment/backend -n $NAMESPACE"
    echo "   kubectl rollout restart deployment/frontend -n $NAMESPACE"
}

# Function to verify secret usage
verify_secret_usage() {
    echo "Verifying secret usage in deployments..."
    
    echo ""
    echo "Backend deployment secret references:"
    kubectl get deployment backend -n "$NAMESPACE" -o yaml | grep -A 5 "secretKeyRef" || echo "No secret references found"
    
    echo ""
    echo "PostgreSQL deployment secret references:"
    kubectl get statefulset postgresql -n "$NAMESPACE" -o yaml | grep -A 5 "secretKeyRef" || echo "No secret references found"
}

# Function to display help
show_help() {
    cat << EOF
Secret Management Script for BMI Health Tracker

Usage: ./secrets-management.sh [COMMAND] [ARGS]

Commands:
    create              Create all secrets in the cluster
    list                List all secrets in the namespace
    describe <name>     Describe a specific secret (shows keys, but not values)
    decode <name> <key> Decode and display a secret value (use with caution)
    update <name>       Update a specific secret from its manifest
    delete              Delete all secrets from the cluster
    rotate              Display secret rotation procedures
    verify              Verify secret usage in deployments
    help                Show this help message

Examples:
    ./secrets-management.sh create
    ./secrets-management.sh list
    ./secrets-management.sh describe db-credentials
    ./secrets-management.sh decode db-credentials password
    ./secrets-management.sh update api-keys
    ./secrets-management.sh rotate

Security Notes:
    - Never commit plain-text secrets to version control
    - Always use Base64 encoding for secret values
    - For production, consider using sealed-secrets or external secret managers
    - Restrict access to secret manifests using RBAC
    - Regularly rotate secrets and update deployments

EOF
}

# Main script logic
main() {
    local command=$1
    
    case "$command" in
        create)
            create_secrets
            ;;
        list)
            list_secrets
            ;;
        describe)
            describe_secret "$2"
            ;;
        decode)
            decode_secret "$2" "$3"
            ;;
        update)
            update_secret "$2"
            ;;
        delete)
            delete_secrets
            ;;
        rotate)
            rotate_secrets
            ;;
        verify)
            verify_secret_usage
            ;;
        help|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
