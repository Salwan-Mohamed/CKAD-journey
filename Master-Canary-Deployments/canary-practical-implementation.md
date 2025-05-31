# 🛠 Practical Kubernetes Canary Deployment Implementation

> **Hands-on tutorial**: Build a complete canary deployment from scratch using real application examples

## 🎯 What You'll Build

By the end of this tutorial, you'll have:
- A PowerShell web application with two versions
- Complete canary deployment pipeline 
- Monitoring and testing setup
- Automated rollback procedures

## 🔧 Prerequisites

```bash
# Verify these tools are installed
kubectl version --client
docker --version
git --version

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

## 🏗 Environment Setup

### Step 1: Create Project Structure

```bash
# Create working directory
mkdir deployment-migration && cd deployment-migration

# Create application directories
mkdir -p {v1,v2,k8s}

# Verify structure
tree .
# .
# ├── v1/
# ├── v2/
# └── k8s/
```

### Step 2: Cluster Preparation

```bash
# Create dedicated namespace
kubectl create namespace canary-demo

# Verify namespace
kubectl get namespaces | grep canary-demo

# Set default namespace (optional)
kubectl config set-context --current --namespace=canary-demo
```

## 💻 Building Sample Applications

### Version 1 Application

**Create `v1/webapp.ps1`:**
```powershell
Start-PodeServer -ScriptBlock {
    # Add endpoint listener
    Add-PodeEndpoint -Address 0.0.0.0 -Port 80 -Protocol Http
    
    # Health check endpoint
    Add-PodeRoute -Method Get -Path '/health' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            status = "healthy"
            version = "1.0"
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    # Main application endpoint
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeHtmlResponse -Value @"
<!DOCTYPE html>
<html>
<head>
    <title>CBT Nuggets - Version 1.0</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f8ff; }
        h1 { color: #1e3a8a; margin-bottom: 20px; }
        .version { background: #3b82f6; color: white; padding: 10px; border-radius: 5px; }
        .timestamp { margin-top: 20px; color: #666; }
    </style>
</head>
<body>
    <h1>Welcome to CBT Nuggets Training Platform</h1>
    <div class="version">Version 1.0 - Stable Release</div>
    <div class="timestamp">Served at: $(Get-Date)</div>
    <p>This is the stable version of our application.</p>
</body>
</html>
"@
    }
}
```

**Create `v1/Dockerfile`:**
```dockerfile
FROM mcr.microsoft.com/powershell:latest

# Set PowerShell as default shell
SHELL ["pwsh", "-Command"]

# Install Pode web framework
RUN Install-Module -Name Pode -Force -Scope AllUsers

# Set working directory
WORKDIR /app

# Copy application file
COPY webapp.ps1 /app/

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pwsh -Command "try { Invoke-WebRequest -Uri http://localhost/health -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }"

# Start application
CMD ["pwsh", "-File", "/app/webapp.ps1"]
```

**Create `v1/build.sh`:**
```bash
#!/bin/bash
set -e

echo "📦 Building version 1.0..."

# Build image
docker build -t cbtnuggets-webapp:v1.0 .

# Tag for registry (replace with your registry)
docker tag cbtnuggets-webapp:v1.0 your-registry.com/cbtnuggets-webapp:v1.0

# Push to registry
docker push your-registry.com/cbtnuggets-webapp:v1.0

echo "✅ Version 1.0 built and pushed successfully!"
```

### Version 2 Application

**Create `v2/webapp.ps1`:**
```powershell
Start-PodeServer -ScriptBlock {
    # Add endpoint listener
    Add-PodeEndpoint -Address 0.0.0.0 -Port 80 -Protocol Http
    
    # Enhanced health check with more details
    Add-PodeRoute -Method Get -Path '/health' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            status = "healthy"
            version = "2.2"
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            uptime = [System.Diagnostics.Process]::GetCurrentProcess().TotalProcessorTime.TotalSeconds
            memory_mb = [math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 2)
        }
    }
    
    # Enhanced main application endpoint
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeHtmlResponse -Value @"
<!DOCTYPE html>
<html>
<head>
    <title>CBT Nuggets - Version 2.2</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0fff0; }
        h1 { color: #059669; margin-bottom: 20px; }
        .version { background: #10b981; color: white; padding: 10px; border-radius: 5px; }
        .features { margin: 30px 0; text-align: left; max-width: 600px; margin: 30px auto; }
        .feature { background: #d1fae5; padding: 10px; margin: 5px 0; border-radius: 5px; }
        .timestamp { margin-top: 20px; color: #666; }
        .new-badge { background: #ef4444; color: white; padding: 3px 8px; border-radius: 3px; font-size: 0.8em; }
    </style>
</head>
<body>
    <h1>Welcome to CBT Nuggets Training Platform</h1>
    <div class="version">Version 2.2 - Enhanced Release <span class="new-badge">NEW</span></div>
    
    <div class="features">
        <h3>New Features:</h3>
        <div class="feature">✨ Enhanced Performance - 50% faster load times</div>
        <div class="feature">📊 Advanced Analytics - Real-time learning metrics</div>
        <div class="feature">🔒 Improved Security - Enhanced authentication</div>
        <div class="feature">📡 Better API - RESTful endpoints for integrations</div>
    </div>
    
    <div class="timestamp">Served at: $(Get-Date)</div>
    <p>This is the new enhanced version with improved features!</p>
</body>
</html>
"@
    }
    
    # New API endpoint (demonstrating new functionality)
    Add-PodeRoute -Method Get -Path '/api/stats' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            version = "2.2"
            features = @("analytics", "enhanced-auth", "performance-boost")
            performance = @{
                response_time_ms = Get-Random -Minimum 50 -Maximum 150
                memory_usage_mb = [math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 2)
                cpu_usage_percent = Get-Random -Minimum 5 -Maximum 25
            }
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    }
}
```

**Copy Dockerfile and create build script for v2:**
```bash
# Copy Dockerfile to v2
cp v1/Dockerfile v2/

# Create v2 build script
cat > v2/build.sh << 'EOF'
#!/bin/bash
set -e

echo "📦 Building version 2.2..."

# Build image
docker build -t cbtnuggets-webapp:v2.2 .

# Tag for registry
docker tag cbtnuggets-webapp:v2.2 your-registry.com/cbtnuggets-webapp:v2.2

# Push to registry
docker push your-registry.com/cbtnuggets-webapp:v2.2

echo "✅ Version 2.2 built and pushed successfully!"
EOF

chmod +x v2/build.sh
```

## 📜 Kubernetes Manifests

### Step 1: Registry Secret

**Create `k8s/registry-secret.yaml`:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: canary-demo
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>

# To generate the secret:
# kubectl create secret docker-registry registry-secret \
#   --docker-server=your-registry.com \
#   --docker-username=your-username \
#   --docker-password=your-password \
#   --namespace=canary-demo \
#   --dry-run=client -o yaml > k8s/registry-secret.yaml
```

### Step 2: Version 1 Deployment

**Create `k8s/v1-deployment.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cbtnuggets-webapp-v1
  namespace: canary-demo
  labels:
    app-name: cbtnuggets-webapp
    app-version: v1.0
    deployment-type: stable
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app-name: cbtnuggets-webapp
      app-version: v1.0
  template:
    metadata:
      labels:
        app-name: cbtnuggets-webapp
        app-version: v1.0
        deployment-type: stable
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/health"
    spec:
      imagePullSecrets:
      - name: registry-secret
      securityContext:
        runAsNonRoot: false  # PowerShell container requires root for some operations
        fsGroup: 2000
      containers:
      - name: webapp
        image: your-registry.com/cbtnuggets-webapp:v1.0
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        env:
        - name: VERSION
          value: "1.0"
        - name: ENVIRONMENT
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 30
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: cbtnuggets-webapp-svc
  namespace: canary-demo
  labels:
    app-name: cbtnuggets-webapp
spec:
  type: LoadBalancer  # Change to ClusterIP for internal testing
  selector:
    app-version: v1.0  # Initially routes only to v1
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  sessionAffinity: None
```

### Step 3: Version 2 Deployment

**Create `k8s/v2-deployment.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cbtnuggets-webapp-v2
  namespace: canary-demo
  labels:
    app-name: cbtnuggets-webapp
    app-version: v2.2
    deployment-type: canary
spec:
  replicas: 1  # Start with minimal replicas for canary
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app-name: cbtnuggets-webapp
      app-version: v2.2
  template:
    metadata:
      labels:
        app-name: cbtnuggets-webapp
        app-version: v2.2
        deployment-type: canary
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/health"
    spec:
      imagePullSecrets:
      - name: registry-secret
      securityContext:
        runAsNonRoot: false
        fsGroup: 2000
      containers:
      - name: webapp
        image: your-registry.com/cbtnuggets-webapp:v2.2
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        env:
        - name: VERSION
          value: "2.2"
        - name: ENVIRONMENT
          value: "production"
        - name: FEATURE_FLAGS
          value: "analytics,enhanced-auth,performance-boost"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 30
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

## 🚀 Step-by-Step Deployment Process

### Phase 1: Build and Push Images

```bash
# Build version 1
cd v1
./build.sh
cd ..

# Build version 2
cd v2
./build.sh
cd ..

# Verify images in registry
docker images | grep cbtnuggets-webapp
```

### Phase 2: Deploy Stable Version (v1)

```bash
# Create registry secret
kubectl create secret docker-registry registry-secret \
  --docker-server=your-registry.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --namespace=canary-demo

# Deploy v1
kubectl apply -f k8s/v1-deployment.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/cbtnuggets-webapp-v1 -n canary-demo

# Verify deployment
kubectl get pods -n canary-demo -l app-version=v1.0
kubectl get service -n canary-demo
```

### Phase 3: Test Version 1

```bash
# Create test client pod
kubectl run client --image=mcr.microsoft.com/powershell \
  --rm -it --namespace=canary-demo -- pwsh

# Inside the client pod:
# Test the service
$ProgressPreference = "SilentlyContinue"
while($true) {
    try {
        $response = Invoke-WebRequest -Uri "http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local" -UseBasicParsing
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Status: $($response.StatusCode) - Content: $($response.Content.Substring(0, 100))..."
    } catch {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - ERROR: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 2
}

# Exit with Ctrl+C, then exit the pod
exit
```

### Phase 4: Deploy Canary Version (v2)

```bash
# Deploy v2 canary
kubectl apply -f k8s/v2-deployment.yaml

# Wait for v2 to be ready
kubectl rollout status deployment/cbtnuggets-webapp-v2 -n canary-demo

# Verify both versions are running
kubectl get pods -n canary-demo --show-labels
```

### Phase 5: Begin Canary Traffic Distribution

**Create `k8s/service-canary.yaml`:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cbtnuggets-webapp-svc
  namespace: canary-demo
  labels:
    app-name: cbtnuggets-webapp
spec:
  type: LoadBalancer
  selector:
    app-name: cbtnuggets-webapp  # Routes to both v1 and v2
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  sessionAffinity: None
```

```bash
# Update service to route to both versions
kubectl apply -f k8s/service-canary.yaml

# Check service endpoints
kubectl describe service cbtnuggets-webapp-svc -n canary-demo

# Current traffic distribution: 75% v1 (3 pods), 25% v2 (1 pod)
```

### Phase 6: Monitor Canary Traffic

```bash
# Start monitoring in a separate terminal
kubectl run client --image=mcr.microsoft.com/powershell \
  --rm -it --namespace=canary-demo -- pwsh

# Enhanced monitoring script
$ProgressPreference = "SilentlyContinue"
$v1Count = 0
$v2Count = 0
$totalRequests = 0

while($true) {
    try {
        $response = Invoke-WebRequest -Uri "http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local" -UseBasicParsing
        $totalRequests++
        
        if ($response.Content -like "*Version 1.0*") {
            $v1Count++
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - V1.0 Response" -ForegroundColor Blue
        } elseif ($response.Content -like "*Version 2.2*") {
            $v2Count++
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - V2.2 Response" -ForegroundColor Green
        }
        
        # Show statistics every 10 requests
        if ($totalRequests % 10 -eq 0) {
            $v1Percent = if ($totalRequests -gt 0) { [math]::Round(($v1Count / $totalRequests) * 100, 1) } else { 0 }
            $v2Percent = if ($totalRequests -gt 0) { [math]::Round(($v2Count / $totalRequests) * 100, 1) } else { 0 }
            Write-Host "\n=== TRAFFIC DISTRIBUTION ==="
            Write-Host "Total Requests: $totalRequests"
            Write-Host "V1.0: $v1Count ($v1Percent%)"
            Write-Host "V2.2: $v2Count ($v2Percent%)"
            Write-Host "===========================\n"
        }
        
    } catch {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}
```

### Phase 7: Progressive Traffic Increase

```bash
# Increase v2 to 50% traffic (scale v2 to 3 replicas)
kubectl scale deployment cbtnuggets-webapp-v2 --replicas=3 -n canary-demo

# Wait for scaling
kubectl rollout status deployment/cbtnuggets-webapp-v2 -n canary-demo

# Verify new distribution: 50% v1 (3 pods), 50% v2 (3 pods)
kubectl get pods -n canary-demo -l app-name=cbtnuggets-webapp
```

```bash
# Increase v2 to 75% traffic (scale down v1 to 1 replica)
kubectl scale deployment cbtnuggets-webapp-v1 --replicas=1 -n canary-demo

# New distribution: 25% v1 (1 pod), 75% v2 (3 pods)
kubectl get pods -n canary-demo -l app-name=cbtnuggets-webapp
```

### Phase 8: Complete Migration

**Create `k8s/service-final.yaml`:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cbtnuggets-webapp-svc
  namespace: canary-demo
  labels:
    app-name: cbtnuggets-webapp
spec:
  type: LoadBalancer
  selector:
    app-version: v2.2  # Route only to v2
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  sessionAffinity: None
```

```bash
# Complete migration to v2
kubectl apply -f k8s/service-final.yaml

# Verify 100% traffic goes to v2
# Monitor should show only "Version 2.2" responses

# Optional: Scale down v1 to 0 (keep for quick rollback)
kubectl scale deployment cbtnuggets-webapp-v1 --replicas=0 -n canary-demo
```

## 📊 Monitoring and Validation

### Health Check Monitoring

```bash
# Monitor pod health
watch "kubectl get pods -n canary-demo -o wide"

# Check deployment status
kubectl describe deployment cbtnuggets-webapp-v2 -n canary-demo

# Monitor resource usage
kubectl top pods -n canary-demo

# Check service endpoints
kubectl get endpoints cbtnuggets-webapp-svc -n canary-demo
```

### Application Metrics

```bash
# Test health endpoints
kubectl run client --image=curlimages/curl --rm -it --namespace=canary-demo -- sh

# Inside client pod:
# Test v2 health endpoint
curl -s http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local/health | jq .

# Test new API endpoint (v2 only)
curl -s http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local/api/stats | jq .

exit
```

### Log Monitoring

```bash
# Monitor all pods logs
kubectl logs -f -l app-name=cbtnuggets-webapp -n canary-demo --tail=50

# Monitor specific version logs
kubectl logs -f -l app-version=v2.2 -n canary-demo

# Monitor events
kubectl get events -n canary-demo --sort-by='.lastTimestamp'
```

## 🚨 Emergency Rollback Procedures

### Quick Rollback Script

**Create `k8s/rollback.sh`:**
```bash
#!/bin/bash
set -e

echo "🚨 EMERGENCY ROLLBACK INITIATED"
echo "$(date): Starting rollback to v1.0"

# Immediate traffic cutover to v1
echo "Step 1: Routing traffic to v1.0..."
kubectl patch service cbtnuggets-webapp-svc -n canary-demo -p '{
  "spec": {
    "selector": {
      "app-version": "v1.0"
    }
  }
}'

# Scale up v1 if needed
echo "Step 2: Scaling up v1.0..."
kubectl scale deployment cbtnuggets-webapp-v1 --replicas=3 -n canary-demo

# Wait for v1 to be ready
echo "Step 3: Waiting for v1.0 to be ready..."
kubectl rollout status deployment/cbtnuggets-webapp-v1 -n canary-demo --timeout=60s

# Scale down v2
echo "Step 4: Scaling down v2.2..."
kubectl scale deployment cbtnuggets-webapp-v2 --replicas=0 -n canary-demo

echo "✅ ROLLBACK COMPLETED"
echo "$(date): All traffic routed to stable v1.0"
echo "Verify with: kubectl get pods -n canary-demo"
```

```bash
# Make rollback script executable
chmod +x k8s/rollback.sh

# Test rollback (if needed)
# ./k8s/rollback.sh
```

## 🎓 Validation and Testing

### End-to-End Testing

```bash
# Create comprehensive test script
cat > k8s/test-canary.sh << 'EOF'
#!/bin/bash

echo "🧪 Starting Canary Deployment Tests..."

# Test 1: Verify both versions are responding
echo "\nTest 1: Version Distribution Test"
kubectl run test-client --image=curlimages/curl --rm --namespace=canary-demo \
  --restart=Never -- sh -c '
    v1_count=0
    v2_count=0
    
    for i in $(seq 1 20); do
      response=$(curl -s http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local)
      if echo "$response" | grep -q "Version 1.0"; then
        v1_count=$((v1_count + 1))
      elif echo "$response" | grep -q "Version 2.2"; then
        v2_count=$((v2_count + 1))
      fi
    done
    
    echo "V1.0 responses: $v1_count"
    echo "V2.2 responses: $v2_count"
    
    if [ $v2_count -gt 0 ]; then
      echo "✅ Canary traffic detected"
    else
      echo "❌ No canary traffic found"
      exit 1
    fi
'

# Test 2: Health check validation
echo "\nTest 2: Health Check Validation"
kubectl run health-test --image=curlimages/curl --rm --namespace=canary-demo \
  --restart=Never -- sh -c '
    health_response=$(curl -s http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local/health)
    echo "Health response: $health_response"
    
    if echo "$health_response" | grep -q "healthy"; then
      echo "✅ Health check passed"
    else
      echo "❌ Health check failed"
      exit 1
    fi
'

# Test 3: New API endpoint (v2 only)
echo "\nTest 3: New API Endpoint Test"
kubectl run api-test --image=curlimages/curl --rm --namespace=canary-demo \
  --restart=Never -- sh -c '
    api_response=$(curl -s http://cbtnuggets-webapp-svc.canary-demo.svc.cluster.local/api/stats)
    echo "API response: $api_response"
    
    if echo "$api_response" | grep -q "analytics"; then
      echo "✅ New API endpoint working"
    else
      echo "⚠️  New API endpoint not accessible (normal if only v1 pods are responding)"
    fi
'

echo "\n🎉 All tests completed!"
EOF

chmod +x k8s/test-canary.sh

# Run tests
./k8s/test-canary.sh
```

## 🎆 Cleanup (Optional)

```bash
# Clean up all resources
kubectl delete namespace canary-demo

# Or selective cleanup
kubectl delete deployment cbtnuggets-webapp-v1 cbtnuggets-webapp-v2 -n canary-demo
kubectl delete service cbtnuggets-webapp-svc -n canary-demo
kubectl delete secret registry-secret -n canary-demo

# Remove local images
docker rmi cbtnuggets-webapp:v1.0 cbtnuggets-webapp:v2.2
```

## 🎓 Next Steps

Congratulations! You've successfully implemented a complete canary deployment. Continue learning with:

1. **[Advanced Strategies](canary-advanced-strategies.md)** - Service mesh, automation, and CI/CD
2. **[Troubleshooting Guide](canary-troubleshooting.md)** - Common issues and debugging
3. **[YAML Examples](canary-yaml-examples.md)** - More production configurations

---

**🎆 Well done! You've mastered hands-on canary deployments with Kubernetes!**