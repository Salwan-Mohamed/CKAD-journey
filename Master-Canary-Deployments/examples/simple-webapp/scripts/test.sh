#!/bin/bash
# Simple Web App Canary Testing Script

set -e

NAMESPACE="canary-demo"
REQUESTS=20
VERBOSE=false
CONTINUOUS=false

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

Test simple web app canary deployment traffic distribution

Options:
    -n, --namespace NAMESPACE   Kubernetes namespace (default: canary-demo)
    -r, --requests NUMBER       Number of test requests (default: 20)
    -v, --verbose              Enable verbose output
    -c, --continuous           Continuous monitoring mode
    -h, --help                 Show this help message

Examples:
    $0                         # Test with defaults
    $0 -r 50 -v              # 50 requests with verbose output
    $0 -c                     # Continuous monitoring
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--requests)
                REQUESTS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--continuous)
                CONTINUOUS=true
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

check_deployment() {
    log_info "Checking deployment status..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    # Check if service exists
    if ! kubectl get service webapp-service -n "$NAMESPACE" &> /dev/null; then
        log_error "Service webapp-service not found in namespace $NAMESPACE"
        exit 1
    fi
    
    # Check if pods are ready
    local ready_pods
    ready_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=webapp --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [[ "$ready_pods" -eq 0 ]]; then
        log_error "No ready pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    log_success "Found $ready_pods ready pods"
}

get_current_distribution() {
    local v1_pods v2_pods total_pods
    
    v1_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/version=v1.0 --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    v2_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/version=v2.0 --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    total_pods=$((v1_pods + v2_pods))
    
    if [[ "$total_pods" -gt 0 ]]; then
        local v1_percent v2_percent
        v1_percent=$(( (v1_pods * 100) / total_pods ))
        v2_percent=$(( (v2_pods * 100) / total_pods ))
        
        echo "Expected distribution based on pod count:"
        echo "  v1.0: $v1_pods pods (~$v1_percent%)"
        echo "  v2.0: $v2_pods pods (~$v2_percent%)"
    else
        echo "No running pods found"
    fi
}

test_traffic_once() {
    local requests=$1
    local v1_count=0
    local v2_count=0
    local error_count=0
    
    log_info "Testing traffic distribution with $requests requests..."
    
    # Create a temporary pod for testing
    local pod_name="test-client-$(date +%s)"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Creating test client pod: $pod_name"
    fi
    
    # Generate test script
    local test_script="
for i in \$(seq 1 $requests); do
    response=\$(curl -s -m 5 http://webapp-service.$NAMESPACE.svc.cluster.local 2>/dev/null)
    if echo "\$response" | grep -q "Version 1.0"; then
        echo "v1"
    elif echo "\$response" | grep -q "Version 2.0"; then
        echo "v2"
    else
        echo "error"
    fi
done
"
    
    # Run the test
    local results
    results=$(kubectl run "$pod_name" --image=curlimages/curl --rm -it --restart=Never --namespace="$NAMESPACE" -- sh -c "$test_script" 2>/dev/null)
    
    # Count results
    while IFS= read -r line; do
        case "$line" in
            "v1")
                ((v1_count++))
                ;;
            "v2")
                ((v2_count++))
                ;;
            "error")
                ((error_count++))
                ;;
        esac
    done <<< "$results"
    
    # Calculate percentages
    local total_successful=$((v1_count + v2_count))
    local v1_percent=0
    local v2_percent=0
    
    if [[ "$total_successful" -gt 0 ]]; then
        v1_percent=$(( (v1_count * 100) / total_successful ))
        v2_percent=$(( (v2_count * 100) / total_successful ))
    fi
    
    # Display results
    echo
    echo "Traffic Distribution Results:"
    echo "============================="
    echo "Total Requests: $requests"
    echo "Successful: $total_successful"
    echo "Errors: $error_count"
    echo
    echo "Version Distribution:"
    printf "  v1.0: %3d requests (%3d%%)\n" "$v1_count" "$v1_percent"
    printf "  v2.0: %3d requests (%3d%%)\n" "$v2_count" "$v2_percent"
    echo
    
    # Health assessment
    if [[ "$error_count" -gt $((requests / 10)) ]]; then  # More than 10% errors
        log_warning "High error rate detected: $error_count/$requests errors"
    elif [[ "$error_count" -gt 0 ]]; then
        log_warning "Some errors detected: $error_count/$requests errors"
    else
        log_success "All requests successful"
    fi
    
    return $error_count
}

continuous_monitoring() {
    log_info "Starting continuous monitoring (Press Ctrl+C to stop)..."
    
    local iteration=1
    
    while true; do
        echo
        echo "=== Iteration $iteration ($(date)) ==="
        
        test_traffic_once 10
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo
            echo "Current Pod Status:"
            kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=webapp -o wide
        fi
        
        echo
        echo "Waiting 30 seconds before next test..."
        sleep 30
        
        ((iteration++))
    done
}

show_service_info() {
    log_info "Current service configuration:"
    
    echo
    echo "Service Details:"
    kubectl get service webapp-service -n "$NAMESPACE" -o yaml | grep -A 10 "spec:"
    
    echo
    echo "Service Endpoints:"
    kubectl get endpoints webapp-service -n "$NAMESPACE" -o wide
    
    echo
    get_current_distribution
}

main() {
    parse_args "$@"
    
    echo "Simple Web App Canary Traffic Testing"
    echo "====================================="
    echo
    
    check_deployment
    
    if [[ "$VERBOSE" == "true" ]]; then
        show_service_info
        echo
    fi
    
    if [[ "$CONTINUOUS" == "true" ]]; then
        continuous_monitoring
    else
        test_traffic_once "$REQUESTS"
        
        if [[ $? -eq 0 ]]; then
            log_success "Traffic test completed successfully"
        else
            log_warning "Traffic test completed with some errors"
        fi
    fi
    
    echo
    log_info "Useful commands:"
    echo "  Change to canary mode: kubectl patch service webapp-service -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"app.kubernetes.io/name\":\"webapp\"}}}'"
    echo "  Route to v2 only: kubectl patch service webapp-service -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"app.kubernetes.io/name\":\"webapp\",\"app.kubernetes.io/version\":\"v2.0\"}}}'"
    echo "  Rollback to v1: kubectl patch service webapp-service -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"app.kubernetes.io/name\":\"webapp\",\"app.kubernetes.io/version\":\"v1.0\"}}}'"
}

main "$@"