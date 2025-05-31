# 📜 Canary Deployment Examples

> **Ready-to-use examples** for different scenarios and use cases

## 📋 Available Examples

### Basic Examples
- **[Simple Web App](simple-webapp/)** - Basic canary with 2 versions
- **[Microservice](microservice/)** - Service-to-service canary
- **[Database Migration](database-migration/)** - Canary with DB changes

### Advanced Examples  
- **[Multi-Region](multi-region/)** - Cross-region canary
- **[Feature Flags](feature-flags/)** - Canary with feature toggles
- **[A/B Testing](ab-testing/)** - User cohort-based deployment

### Service Mesh Examples
- **[Istio Integration](istio/)** - Complete Istio setup
- **[Linkerd Integration](linkerd/)** - Linkerd traffic splitting
- **[Ambassador](ambassador/)** - Ambassador edge stack

### CI/CD Examples
- **[GitLab Pipeline](gitlab-cicd/)** - Complete GitLab automation
- **[GitHub Actions](github-actions/)** - GitHub workflow
- **[ArgoCD](argocd/)** - GitOps with ArgoCD
- **[Tekton](tekton/)** - Cloud-native CI/CD

## 🚀 Quick Start Examples

### 5-Minute Demo

```bash
# Clone examples
git clone https://github.com/Salwan-Mohamed/CKAD-journey.git
cd CKAD-journey/Master-Canary-Deployments/examples

# Run simple webapp example
kubectl apply -f simple-webapp/

# Watch deployment
kubectl get pods -w -n canary-demo

# Test traffic distribution
kubectl run client --image=curlimages/curl --rm -it -- sh
# Inside pod:
for i in {1..20}; do curl -s http://webapp-service.canary-demo.svc.cluster.local | grep Version; done
```

### Production Example

```bash
# Deploy production-ready setup
kubectl apply -f microservice/namespace.yaml
kubectl apply -f microservice/secrets/
kubectl apply -f microservice/configmaps/
kubectl apply -f microservice/deployments/
kubectl apply -f microservice/services/
kubectl apply -f microservice/monitoring/

# Monitor with Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000
```

## 📊 Example Structure

Each example follows this structure:

```
example-name/
├── README.md                 # Example-specific documentation
├── namespace.yaml            # Kubernetes namespace
├── configmaps/
│   ├── app-config.yaml
│   └── monitoring-config.yaml
├── secrets/
│   └── app-secrets.yaml
├── deployments/
│   ├── v1-deployment.yaml
│   └── v2-deployment.yaml
├── services/
│   ├── app-service.yaml
│   └── monitoring-service.yaml
├── monitoring/
│   ├── servicemonitor.yaml
│   ├── alerts.yaml
│   └── dashboard.json
├── scripts/
│   ├── deploy.sh
│   ├── test.sh
│   └── cleanup.sh
└── tests/
    ├── integration-test.yaml
    └── load-test.yaml
```

## 🎯 Use Case Matrix

| Example | Complexity | Service Mesh | Monitoring | CI/CD | Best For |
|---------|------------|--------------|------------|-------|----------|
| Simple Web App | ⭐ | ❌ | Basic | Manual | Learning |
| Microservice | ⭐⭐ | Optional | Full | Manual | Development |
| Multi-Region | ⭐⭐⭐ | Required | Advanced | GitOps | Enterprise |
| Feature Flags | ⭐⭐ | Optional | Full | Automated | Product |
| A/B Testing | ⭐⭐⭐ | Required | Advanced | Automated | Product |
| Database Migration | ⭐⭐⭐ | Optional | Full | Manual | Data Heavy |

## 🋠 Customization Guide

### Adapting Examples

1. **Change Application**
   ```bash
   # Update image references
   sed -i 's/nginx:1.20/your-app:v1.0/g' deployments/*.yaml
   
   # Update service ports
   sed -i 's/port: 80/port: 8080/g' services/*.yaml
   ```

2. **Modify Traffic Split**
   ```bash
   # Change initial canary percentage
   # Edit service selector or VirtualService weights
   ```

3. **Add Monitoring**
   ```bash
   # Copy monitoring configs
   cp ../microservice/monitoring/* ./monitoring/
   
   # Update labels and selectors
   ```

### Environment Variables

Most examples support these environment variables:

```bash
export NAMESPACE="my-canary"
export APP_NAME="my-app"
export STABLE_VERSION="v1.0"
export CANARY_VERSION="v2.0"
export REGISTRY="my-registry.com"
export CANARY_PERCENTAGE="10"

# Deploy with custom values
envsubst < deployment-template.yaml | kubectl apply -f -
```

## 🧪 Testing Examples

### Validation Script

```bash
#!/bin/bash
# validate-example.sh

EXAMPLE_DIR=$1
NAMESPACE=${2:-canary-demo}

if [ -z "$EXAMPLE_DIR" ]; then
    echo "Usage: $0 <example-directory> [namespace]"
    exit 1
fi

echo "🧪 Testing example: $EXAMPLE_DIR"

# Deploy example
echo "Deploying example..."
kubectl apply -f "$EXAMPLE_DIR/"

# Wait for pods
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webapp -n "$NAMESPACE" --timeout=300s

# Test connectivity
echo "Testing connectivity..."
kubectl run test-client --image=curlimages/curl --rm -it --restart=Never --namespace="$NAMESPACE" -- sh -c '
for i in $(seq 1 10); do
  curl -s http://webapp-service/health || echo "Failed request $i"
done'

# Check metrics (if monitoring enabled)
if kubectl get servicemonitor -n monitoring webapp-monitor &>/dev/null; then
    echo "Checking metrics availability..."
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
    sleep 5
    curl -s "http://localhost:9090/api/v1/query?query=up{job='webapp'}" | jq '.data.result'
    pkill -f "kubectl port-forward"
fi

echo "✅ Example validation completed!"
```

### Load Testing

```yaml
# load-test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: canary-load-test
  namespace: canary-demo
spec:
  template:
    spec:
      containers:
      - name: load-test
        image: loadimpact/k6:latest
        command:
        - k6
        - run
        - -
        stdin: true
        stdinOnce: true
        env:
        - name: TARGET_URL
          value: "http://webapp-service.canary-demo.svc.cluster.local"
      restartPolicy: Never
      stdin: true
  backoffLimit: 1
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-test-script
  namespace: canary-demo
data:
  test.js: |
    import http from 'k6/http';
    import { check, sleep } from 'k6';
    
    export let options = {
      stages: [
        { duration: '2m', target: 10 },  // Ramp up
        { duration: '5m', target: 10 },  // Stay at 10 users
        { duration: '2m', target: 0 },   // Ramp down
      ],
      thresholds: {
        http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
        http_req_failed: ['rate<0.1'],     // Error rate under 10%
      },
    };
    
    export default function() {
      let response = http.get(`${__ENV.TARGET_URL}/api/health`);
      
      check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 500ms': (r) => r.timings.duration < 500,
      });
      
      // Test different endpoints
      http.get(`${__ENV.TARGET_URL}/api/users`);
      http.post(`${__ENV.TARGET_URL}/api/events`, JSON.stringify({
        event: 'page_view',
        user_id: Math.floor(Math.random() * 1000)
      }), {
        headers: { 'Content-Type': 'application/json' },
      });
      
      sleep(1);
    }
```

## 📋 Example Catalog

### By Technology Stack

**Frontend Applications**
- React SPA canary
- Vue.js progressive deployment
- Angular micro-frontend

**Backend Services**
- Node.js REST API
- Python FastAPI
- Go microservice
- Java Spring Boot

**Databases**
- PostgreSQL schema migration
- MongoDB data model changes
- Redis configuration updates

**Message Queues**
- RabbitMQ consumer canary
- Apache Kafka stream processing
- AWS SQS worker deployment

### By Deployment Pattern

**Traffic-Based**
- Percentage-based routing
- Geographic routing
- Device-type routing
- User-segment routing

**Feature-Based**
- Feature flag integration
- A/B testing framework
- Progressive feature rollout
- Beta user programs

**Infrastructure-Based**
- Multi-cluster deployment
- Cross-region failover
- Blue-green with canary
- Rolling deployment hybrid

## 🔗 Integration Examples

### Observability Stack

```bash
# Deploy complete observability
kubectl apply -f examples/observability-stack/

# Includes:
# - Prometheus + Grafana
# - Jaeger tracing
# - FluentD logging
# - AlertManager
# - Custom dashboards
```

### Security Scanning

```bash
# Deploy with security scanning
kubectl apply -f examples/security-scan/

# Includes:
# - Falco runtime security
# - OPA Gatekeeper policies
# - Network policies
# - Pod security standards
```

### Chaos Engineering

```bash
# Deploy with chaos testing
kubectl apply -f examples/chaos-engineering/

# Includes:
# - Chaos Monkey
# - Network partitions
# - Resource exhaustion
# - Pod failures
```

---

**📦 Choose your example and start experimenting with canary deployments!**

*Each example includes detailed README with specific instructions and customization options.*