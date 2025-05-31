#!/bin/bash
# Simple Web App Canary Cleanup Script

set -e

NAMESPACE="canary-demo"
FORCE=false
KEEP_NAMESPACE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Cleanup simple web app canary deployment resources

Options:
    -n, --namespace NAMESPACE   Kubernetes namespace (default: canary-demo)
    -f, --force                Force cleanup without confirmation
    -k, --keep-namespace       Keep the namespace after cleanup
    -h, --help                 Show this help message

Examples:
    $0                         # Interactive cleanup
    $0 -f                     # Force cleanup without confirmation
    $0 -k                     # Cleanup but keep namespace
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -k|--keep-namespace)
                KEEP_NAMESPACE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

confirm_cleanup() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo
    log_warning "This will delete the following resources in namespace '$NAMESPACE':"
    
    # Show what will be deleted
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo
        echo "Deployments:"
        kubectl get deployments -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
        
        echo
        echo "Services:"
        kubectl get services -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
        
        echo
        echo "ConfigMaps:"
        kubectl get configmaps -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
        
        echo
        echo "Pods:"
        kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
        
        if [[ "$KEEP_NAMESPACE" == "false" ]]; then
            echo
            log_warning "The namespace '$NAMESPACE' will also be deleted!"
        fi
    else
        log_info "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    
    echo
    read -p "Are you sure you want to proceed? [y/N]: " -r
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

cleanup_resources() {
    log_info "Starting cleanup of namespace: $NAMESPACE"
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' does not exist"
        return 0
    fi
    
    # Delete deployments
    log_info "Deleting deployments..."
    kubectl delete deployments --all -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
    
    # Delete services
    log_info "Deleting services..."
    kubectl delete services --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
    
    # Delete configmaps
    log_info "Deleting configmaps..."
    kubectl delete configmaps --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
    
    # Delete any remaining pods
    log_info "Deleting any remaining pods..."
    kubectl delete pods --all -n "$NAMESPACE" --timeout=60s --force --grace-period=0 2>/dev/null || true
    
    # Wait for pods to terminate
    log_info "Waiting for pods to terminate..."
    local timeout=60
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local remaining_pods
        remaining_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [[ "$remaining_pods" -eq 0 ]]; then
            break
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # Delete namespace if requested
    if [[ "$KEEP_NAMESPACE" == "false" ]]; then
        log_info "Deleting namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --timeout=120s 2>/dev/null || {
            log_warning "Failed to delete namespace cleanly, forcing deletion..."
            kubectl patch namespace "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        }
    else
        log_info "Keeping namespace: $NAMESPACE"
    fi
}

verify_cleanup() {
    log_info "Verifying cleanup..."
    
    if [[ "$KEEP_NAMESPACE" == "false" ]]; then
        if kubectl get namespace "$NAMESPACE" &> /dev/null; then
            log_warning "Namespace '$NAMESPACE' still exists"
            
            # Check if it's terminating
            local phase
            phase=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
            if [[ "$phase" == "Terminating" ]]; then
                log_info "Namespace is in Terminating state, this is normal"
            fi
        else
            log_success "Namespace '$NAMESPACE' has been deleted"
        fi
    else
        if kubectl get namespace "$NAMESPACE" &> /dev/null; then
            local remaining_resources
            remaining_resources=$(kubectl get all -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
            
            if [[ "$remaining_resources" -eq 0 ]]; then
                log_success "All resources cleaned up from namespace '$NAMESPACE'"
            else
                log_warning "Some resources may still exist in namespace '$NAMESPACE'"
                kubectl get all -n "$NAMESPACE" 2>/dev/null || true
            fi
        else
            log_error "Namespace '$NAMESPACE' was unexpectedly deleted"
        fi
    fi
}

show_cleanup_summary() {
    echo
    log_success "Cleanup completed!"
    
    echo
    log_info "Summary:"
    if [[ "$KEEP_NAMESPACE" == "false" ]]; then
        echo "  - Namespace '$NAMESPACE' and all resources deleted"
    else
        echo "  - All resources deleted from namespace '$NAMESPACE'"
        echo "  - Namespace '$NAMESPACE' preserved"
    fi
    
    echo
    log_info "To redeploy:"
    echo "  ./scripts/deploy.sh -n $NAMESPACE"
}

main() {
    parse_args "$@"
    
    echo "Simple Web App Canary Cleanup"
    echo "=============================="
    echo
    
    confirm_cleanup
    cleanup_resources
    verify_cleanup
    show_cleanup_summary
}

main "$@"