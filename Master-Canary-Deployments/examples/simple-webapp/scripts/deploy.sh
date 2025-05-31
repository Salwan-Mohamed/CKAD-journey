#!/bin/bash
# Simple Web App Canary Deployment Script

set -e

NAMESPACE="canary-demo"
VERBOSE=false
DRY_RUN=false

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

Deploy simple web app canary deployment example

Options:
    -n, --namespace NAMESPACE   Kubernetes namespace (default: canary-demo)
    -v, --verbose              Enable verbose output
    -d, --dry-run              Show what would be deployed without applying
    -h, --help                 Show this help message

Examples:
    $0                         # Deploy with defaults
    $0 -n my-demo -v          # Deploy to custom namespace with verbose output
    $0 -d                     # Dry run to see what would be deployed
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

deploy_resources() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local manifests_dir="$(dirname "$script_dir")"
    
    log_info "Deploying resources to namespace: $NAMESPACE"
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Creating namespace: $NAMESPACE"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] kubectl create namespace $NAMESPACE"
        else
            kubectl create namespace "$NAMESPACE"
        fi
    else
        log_info "Namespace $NAMESPACE already exists"
    fi
    
    # Deploy manifests
    local manifests=(
        "namespace.yaml"
        "configmaps.yaml"
        "v1-deployment.yaml"
        "v2-deployment.yaml"
        "service.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        local manifest_path="$manifests_dir/$manifest"
        
        if [[ -f "$manifest_path" ]]; then
            log_info "Applying $manifest..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[DRY RUN] kubectl apply -f $manifest_path"
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "Contents of $manifest:"
                    cat "$manifest_path"
                    echo "---"
                fi
            else
                if [[ "$VERBOSE" == "true" ]]; then
                    kubectl apply -f "$manifest_path" --namespace="$NAMESPACE"
                else
                    kubectl apply -f "$manifest_path" --namespace="$NAMESPACE" &> /dev/null
                fi
                log_success "Applied $manifest"
            fi
        else
            log_warning "Manifest not found: $manifest_path"
        fi
    done
}

wait_for_pods() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would wait for pods to be ready"
        return
    fi
    
    log_info "Waiting for pods to be ready..."
    
    # Wait for v1 pods
    log_info "Waiting for v1 pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/version=v1.0 -n "$NAMESPACE" --timeout=120s
    
    # Wait for v2 pods
    log_info "Waiting for v2 pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/version=v2.0 -n "$NAMESPACE" --timeout=120s
    
    log_success "All pods are ready"
}

show_status() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would show deployment status"
        return
    fi
    
    log_info "Deployment status:"
    
    echo
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo
    echo "Services:"
    kubectl get services -n "$NAMESPACE"
    
    echo
    echo "Deployments:"
    kubectl get deployments -n "$NAMESPACE"
    
    # Show service details
    echo
    echo "Service Details:"
    kubectl describe service webapp-service -n "$NAMESPACE" | grep -E "(Selector|Endpoints|Port)"
}

show_access_info() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would show access information"
        return
    fi
    
    echo
    log_info "Access Information:"
    
    # Get service type
    local service_type
    service_type=$(kubectl get service webapp-service -n "$NAMESPACE" -o jsonpath='{.spec.type}')
    
    if [[ "$service_type" == "LoadBalancer" ]]; then
        echo "Service Type: LoadBalancer"
        echo "External IP: $(kubectl get service webapp-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo 'Pending...')"
        echo "Port: 80"
        echo
        echo "If external IP is pending, use port forwarding:"
        echo "kubectl port-forward service/webapp-service 8080:80 -n $NAMESPACE"
    else
        echo "Service Type: $service_type"
        echo "To access the service, use port forwarding:"
        echo "kubectl port-forward service/webapp-service 8080:80 -n $NAMESPACE"
    fi
    
    echo
    echo "Test traffic distribution:"
    cat << 'EOF'
kubectl run client --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh -c '
for i in {1..20}; do
  curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*"
done | sort | uniq -c'
EOF
}

main() {
    parse_args "$@"
    
    echo "Simple Web App Canary Deployment"
    echo "================================="
    echo
    
    check_prerequisites
    deploy_resources
    wait_for_pods
    show_status
    show_access_info
    
    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run completed - no resources were actually deployed"
    else
        log_success "Deployment completed successfully!"
        echo
        log_info "Next steps:"
        echo "1. Test the current setup (100% v1.0 traffic)"
        echo "2. Begin canary deployment by updating service selector"
        echo "3. Monitor traffic distribution"
        echo "4. Complete migration to v2.0"
        echo
        echo "For detailed instructions, see: README.md"
    fi
}

main "$@"