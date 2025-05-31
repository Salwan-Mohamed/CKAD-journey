# 🚀 Simple Web App Canary Deployment Example

> **5-minute demo** of basic Kubernetes canary deployment concepts

## 🎯 What You'll Learn

- Basic canary deployment with 2 application versions
- Traffic routing with Kubernetes Services
- Label-based pod selection
- Manual traffic migration process

## 🗺 Architecture

```
[Users] → [LoadBalancer] → [Service] → [Pods v1.0 + v2.0]
                                      ↑
                                 Label Selector
                                      ↑
                            "app.kubernetes.io/name: webapp"
                         "app.kubernetes.io/version: v1.0 OR v2.0"
```

## 🛠 Prerequisites

```bash
# Verify cluster access
kubectl cluster-info

# Check kubectl version
kubectl version --client
```

## 🚀 Quick Start (5 minutes)

### Step 1: Deploy the Application

```bash
# Clone the repository (if not already done)
git clone https://github.com/Salwan-Mohamed/CKAD-journey.git
cd CKAD-journey/Master-Canary-Deployments/examples/simple-webapp

# Deploy all resources
kubectl apply -f .

# Verify deployment
kubectl get all -n canary-demo
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
pod/webapp-v1-xxxxx-xxxxx      1/1     Running   0          30s
pod/webapp-v1-xxxxx-yyyyy      1/1     Running   0          30s
pod/webapp-v1-xxxxx-zzzzz      1/1     Running   0          30s
pod/webapp-v2-xxxxx-aaaaa      1/1     Running   0          30s

NAME                    TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/webapp-service  LoadBalancer   10.245.xxx.xxx  <pending>     80:30001/TCP   30s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/webapp-v1   3/3     3            3           30s
deployment.apps/webapp-v2   1/1     1            1           30s
```

### Step 2: Test Initial Setup (100% v1.0)

```bash
# Check current service configuration
kubectl describe service webapp-service -n canary-demo

# Test from inside cluster
kubectl run client --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh

# Inside the client pod:
for i in {1..10}; do
  curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*"
done

# Expected: All responses show "Version 1.0"
exit
```

### Step 3: Begin Canary Deployment (25% v2.0)

```bash
# Update service to route to both versions
kubectl patch service webapp-service -n canary-demo -p='{
  "spec": {
    "selector": {
      "app.kubernetes.io/name": "webapp"
    }
  }
}'

# Verify traffic distribution
kubectl run client --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh

# Inside the client pod:
echo "Testing traffic distribution:"
for i in {1..20}; do
  curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*"
done | sort | uniq -c

# Expected output (approximately):
#   15 Version 1.0
#    5 Version 2.0
exit
```

### Step 4: Increase Canary Traffic (50% v2.0)

```bash
# Scale up v2 to match v1
kubectl scale deployment webapp-v2 --replicas=3 -n canary-demo

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/version=v2.0 -n canary-demo --timeout=60s

# Test new distribution
kubectl run client --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh

# Inside the client pod:
for i in {1..20}; do
  curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*"
done | sort | uniq -c

# Expected output (approximately):
#   10 Version 1.0
#   10 Version 2.0
exit
```

### Step 5: Complete Migration (100% v2.0)

```bash
# Route all traffic to v2.0
kubectl patch service webapp-service -n canary-demo -p='{
  "spec": {
    "selector": {
      "app.kubernetes.io/name": "webapp",
      "app.kubernetes.io/version": "v2.0"
    }
  }
}'

# Test final state
kubectl run client --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh

# Inside the client pod:
for i in {1..10}; do
  curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*"
done

# Expected: All responses show "Version 2.0"
exit
```

### Step 6: Cleanup Old Version

```bash
# Scale down v1 deployment
kubectl scale deployment webapp-v1 --replicas=0 -n canary-demo

# Verify final state
kubectl get pods -n canary-demo

# Optional: Delete v1 deployment entirely
# kubectl delete deployment webapp-v1 -n canary-demo
```

## 🔍 Monitoring and Verification

### Check Pod Distribution

```bash
# View all pods with labels
kubectl get pods -n canary-demo --show-labels

# Count pods by version
echo "V1 Pods:"
kubectl get pods -n canary-demo -l app.kubernetes.io/version=v1.0 --no-headers | wc -l

echo "V2 Pods:"
kubectl get pods -n canary-demo -l app.kubernetes.io/version=v2.0 --no-headers | wc -l
```

### Service Endpoint Analysis

```bash
# Check which pods are serving traffic
kubectl get endpoints webapp-service -n canary-demo -o yaml

# Describe service for detailed info
kubectl describe service webapp-service -n canary-demo
```

### Real-time Traffic Monitoring

```bash
# Monitor traffic in real-time
kubectl run traffic-monitor --image=curlimages/curl --rm -it --restart=Never --namespace=canary-demo -- sh -c '
v1_count=0
v2_count=0
echo "Starting traffic monitoring... (Press Ctrl+C to stop)"
while true; do
  response=$(curl -s http://webapp-service.canary-demo.svc.cluster.local | grep -o "Version [0-9.]*")
  if echo "$response" | grep -q "Version 1.0"; then
    v1_count=$((v1_count + 1))
    echo "$(date +%H:%M:%S) - V1.0 | Total: v1=$v1_count, v2=$v2_count"
  elif echo "$response" | grep -q "Version 2.0"; then
    v2_count=$((v2_count + 1))
    echo "$(date +%H:%M:%S) - V2.0 | Total: v1=$v1_count, v2=$v2_count"
  fi
  sleep 1
done'
```

## 🚨 Rollback Procedure

If you need to rollback to v1.0:

```bash
# Emergency rollback to v1.0
kubectl patch service webapp-service -n canary-demo -p='{
  "spec": {
    "selector": {
      "app.kubernetes.io/name": "webapp",
      "app.kubernetes.io/version": "v1.0"
    }
  }
}'

# Scale up v1 if needed
kubectl scale deployment webapp-v1 --replicas=3 -n canary-demo

# Scale down v2
kubectl scale deployment webapp-v2 --replicas=0 -n canary-demo

echo "Rollback completed - all traffic routed to v1.0"
```

## 🐛 Troubleshooting

### Issue: Pods Not Starting

```bash
# Check pod status
kubectl describe pods -n canary-demo

# Check events
kubectl get events -n canary-demo --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
```

### Issue: No Traffic to Canary

```bash
# Verify service selector
kubectl get service webapp-service -n canary-demo -o yaml | grep -A 10 selector

# Check pod labels
kubectl get pods -n canary-demo --show-labels

# Test direct pod access
POD_IP=$(kubectl get pod -l app.kubernetes.io/version=v2.0 -n canary-demo -o jsonpath='{.items[0].status.podIP}')
kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl $POD_IP
```

### Issue: External Access Not Working

```bash
# Check LoadBalancer status
kubectl get service webapp-service -n canary-demo

# If using cloud provider, check external IP assignment
kubectl describe service webapp-service -n canary-demo

# Alternative: Use port forwarding for testing
kubectl port-forward service/webapp-service 8080:80 -n canary-demo
# Then access http://localhost:8080
```

## 🔄 Cleanup

```bash
# Delete all resources
kubectl delete namespace canary-demo

# Or delete individual resources
kubectl delete -f . --namespace=canary-demo
```

## 🎓 Key Learning Points

1. **Label Selectors**: Services use label selectors to route traffic to specific pods
2. **Gradual Migration**: Change replica counts to adjust traffic distribution
3. **Zero Downtime**: Both versions run simultaneously during migration
4. **Easy Rollback**: Simply change service selector back to stable version
5. **Monitoring**: Always verify traffic distribution during deployment

## 🚀 Next Steps

After completing this example:

1. **[Advanced Examples](../microservice/)** - More complex scenarios
2. **[Istio Integration](../istio/)** - Service mesh traffic management
3. **[Monitoring Setup](../../monitoring/)** - Add observability
4. **[CI/CD Integration](../gitlab-cicd/)** - Automate deployments

---

**🎉 Congratulations! You've successfully completed your first Kubernetes canary deployment!**

*This example provides the foundation for understanding more advanced canary deployment patterns.*