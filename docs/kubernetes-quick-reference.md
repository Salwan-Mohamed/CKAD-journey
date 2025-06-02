# Kubernetes Architecture Quick Reference Guide

*Essential commands, concepts, and troubleshooting for CKAD success*

## 📐 Core Architecture Components

### Control Plane Components
```bash
# Check control plane health
kubectl get componentstatuses
kubectl get pods -n kube-system

# API Server
kubectl cluster-info
kubectl api-versions
kubectl api-resources

# etcd cluster health
kubectl get pods -n kube-system -l component=etcd

# Scheduler
kubectl get events --field-selector reason=Scheduled

# Controller Manager
kubectl get pods -n kube-system -l component=kube-controller-manager
```

### Worker Node Components
```bash
# Node information
kubectl get nodes -o wide
kubectl describe node <node-name>

# kubelet status
kubectl get pods -A -o wide
kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary

# kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

# Container runtime
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'
```

---

## 🔐 Security Architecture

### RBAC Commands
```bash
# Check permissions
kubectl auth can-i <verb> <resource> --as=<user> --namespace=<ns>
kubectl auth can-i "*" "*" --as=<user>

# Create service account
kubectl create serviceaccount <name> -n <namespace>

# Create role and binding
kubectl create role <role-name> --verb=get,list --resource=pods -n <namespace>
kubectl create rolebinding <binding-name> --role=<role-name> --user=<user> -n <namespace>

# Cluster-wide permissions
kubectl create clusterrole <role-name> --verb=get,list --resource=nodes
kubectl create clusterrolebinding <binding-name> --clusterrole=<role-name> --user=<user>

# Debug RBAC
kubectl describe role <role-name> -n <namespace>
kubectl describe rolebinding <binding-name> -n <namespace>
```

### Security Contexts
```bash
# Check pod security context
kubectl get pod <pod-name> -o jsonpath='{.spec.securityContext}'
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].securityContext}'

# Run as non-root user
kubectl run secure-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# Edit to add: spec.securityContext.runAsUser: 1000
kubectl apply -f pod.yaml
```

---

## 🌐 Networking Architecture

### Service Discovery
```bash
# Services and endpoints
kubectl get services -A
kubectl get endpoints -A
kubectl describe service <service-name>

# DNS resolution testing
kubectl run dns-test --image=busybox --rm -it -- nslookup kubernetes.default.svc.cluster.local
kubectl run dns-test --image=busybox --rm -it -- nslookup <service-name>.<namespace>.svc.cluster.local
```

### Network Policies
```bash
# List network policies
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity (basic)
kubectl run client --image=curlimages/curl --rm -it -- sh
# curl -m 5 http://<service>.<namespace>.svc.cluster.local:<port>

# Test cross-namespace connectivity
kubectl run client -n <source-ns> --image=curlimages/curl --rm -it -- curl -m 5 http://<service>.<target-ns>.svc.cluster.local:<port>
```

---

## 💾 Storage Architecture

### Persistent Volumes
```bash
# Storage classes
kubectl get storageclass
kubectl describe storageclass <storage-class>

# Persistent volumes
kubectl get pv
kubectl describe pv <pv-name>

# Persistent volume claims
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>

# Check volume mounts
kubectl describe pod <pod-name> | grep -A 10 "Volumes:"
kubectl exec <pod-name> -- df -h
```

### Volume Troubleshooting
```bash
# Check volume binding
kubectl get pvc <pvc-name> -o jsonpath='{.status.phase}'
kubectl get events --field-selector involvedObject.name=<pvc-name>

# CSI driver status
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-driver-pod>
```

---

## 🏗️ Multi-Container Pod Patterns

### Sidecar Pattern
```bash
# Check container status in pod
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].name}'
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].ready}'

# Logs from specific container
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> -c <container-name> --previous

# Execute in specific container
kubectl exec -it <pod-name> -c <container-name> -- /bin/sh
```

### Init Containers
```bash
# Check init container status
kubectl get pod <pod-name> -o jsonpath='{.status.initContainerStatuses[*].name}'
kubectl describe pod <pod-name> | grep -A 10 "Init Containers:"

# Init container logs
kubectl logs <pod-name> -c <init-container-name>
```

---

## 📊 Monitoring and Observability

### Resource Usage
```bash
# Node resource usage
kubectl top nodes
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# Pod resource usage
kubectl top pods -A
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --containers
```

### Metrics and Health
```bash
# Cluster metrics
kubectl get --raw /metrics | grep apiserver
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics

# Pod health checks
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -A 10 "Conditions:"
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## 🚀 Deployment Patterns

### Rolling Updates
```bash
# Deployment status
kubectl rollout status deployment/<deployment-name>
kubectl rollout history deployment/<deployment-name>

# Update deployment
kubectl set image deployment/<deployment-name> <container>=<new-image>
kubectl rollout restart deployment/<deployment-name>

# Rollback deployment
kubectl rollout undo deployment/<deployment-name>
kubectl rollout undo deployment/<deployment-name> --to-revision=2
```

### Scaling and Autoscaling
```bash
# Manual scaling
kubectl scale deployment <deployment-name> --replicas=5

# Horizontal Pod Autoscaler
kubectl autoscale deployment <deployment-name> --cpu-percent=70 --min=2 --max=10
kubectl get hpa
kubectl describe hpa <hpa-name>
```

---

## 🛠️ Troubleshooting Commands

### Pod Issues
```bash
# Pod debugging workflow
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous
kubectl exec -it <pod-name> -- /bin/sh

# Pod events
kubectl get events --field-selector involvedObject.name=<pod-name>
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces
```

### Node Issues
```bash
# Node troubleshooting
kubectl describe node <node-name>
kubectl get events --field-selector involvedObject.name=<node-name>
kubectl get pods --field-selector spec.nodeName=<node-name>

# Node conditions
kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'
```

### Networking Issues
```bash
# Service troubleshooting
kubectl get endpoints <service-name>
kubectl get service <service-name> -o wide
kubectl describe service <service-name>

# DNS troubleshooting
kubectl run dns-debug --image=busybox --rm -it -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it <pod-name> -- cat /etc/resolv.conf
```

---

## 🎯 CKAD Exam Quick Tips

### Time-Saving Aliases
```bash
# Essential aliases for speed
alias k='kubectl'
alias kgp='kubectl get pods'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias ke='kubectl explain'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'

# Multi-container specific
alias klc='kubectl logs -c'
alias kexc='kubectl exec -it -c'
```

### Fast YAML Generation
```bash
# Generate YAML quickly
kubectl run <pod-name> --image=<image> --dry-run=client -o yaml > pod.yaml
kubectl create deployment <name> --image=<image> --dry-run=client -o yaml > deployment.yaml
kubectl create service clusterip <name> --tcp=80:8080 --dry-run=client -o yaml > service.yaml

# ConfigMap and Secret generation
kubectl create configmap <name> --from-literal=key=value --dry-run=client -o yaml > cm.yaml
kubectl create secret generic <name> --from-literal=key=value --dry-run=client -o yaml > secret.yaml
```

### Exam Strategy Checklist
- [ ] Read question completely before starting
- [ ] Use `kubectl explain` for field definitions
- [ ] Generate YAML with `--dry-run=client -o yaml`
- [ ] Test with `kubectl apply --dry-run=server`
- [ ] Verify with `kubectl get` and `kubectl describe`
- [ ] Check logs with `kubectl logs`
- [ ] Use `kubectl exec` for debugging

---

## 📋 Common Resource Specs

### Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    app: example
spec:
  containers:
  - name: app
    image: nginx:1.21
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Service Template
```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
spec:
  selector:
    app: example
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
```

### ConfigMap Template
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-config
data:
  key1: value1
  key2: value2
  config.yaml: |
    setting1: value1
    setting2: value2
```

---

## 🔍 Resource Field Quick Reference

### Common Fields
```bash
# Get all possible fields for a resource
kubectl explain pod --recursive
kubectl explain deployment.spec --recursive

# Common paths
kubectl explain pod.spec.containers
kubectl explain pod.spec.securityContext
kubectl explain pod.spec.volumes
kubectl explain service.spec
kubectl explain networkpolicy.spec
```

### JSONPath Examples
```bash
# Pod information
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{.items[*].status.podIP}'
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Node information
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'
```

---

## 🚨 Emergency Commands

### Pod Not Starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous
kubectl get events --field-selector involvedObject.name=<pod-name>
kubectl exec -it <pod-name> -- /bin/sh  # if running
```

### Service Not Working
```bash
kubectl get endpoints <service-name>
kubectl get pods -l <label-selector>
kubectl describe service <service-name>
kubectl run test --image=busybox --rm -it -- wget -O- <service-name>:<port>
```

### Network Policy Blocking
```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name>
kubectl run test --image=busybox --rm -it -- nc -zv <target-ip> <port>
```

---

*Quick Reference Version: June 2025*
*For complete details, see the [Kubernetes Architecture Deep Dive](../kubernetes-architecture-deep-dive.md)*