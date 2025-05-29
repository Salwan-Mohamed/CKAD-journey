# Multi-Container Debugging Commands

## 🔍 Essential Debugging Commands for CKAD

This guide provides essential kubectl commands for debugging multi-container pods, specifically useful during CKAD exam scenarios.

## 📋 Quick Reference Commands

### Pod Inspection
```bash
# List all pods with container count
kubectl get pods -o wide

# Detailed pod information with events
kubectl describe pod <pod-name>

# Get pod YAML configuration
kubectl get pod <pod-name> -o yaml

# Get pod status for all containers
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].name}'
```

### Container-Specific Operations
```bash
# List all containers in a pod
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'

# Get logs from specific container
kubectl logs <pod-name> -c <container-name>

# Follow logs from specific container
kubectl logs <pod-name> -c <container-name> -f

# Get previous container logs (after restart)
kubectl logs <pod-name> -c <container-name> --previous

# Execute command in specific container
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
```

### Multi-Container Log Analysis
```bash
# Get logs from all containers
kubectl logs <pod-name> --all-containers=true

# Get logs from all containers with timestamps
kubectl logs <pod-name> --all-containers=true --timestamps=true

# Get logs from all containers since specific time
kubectl logs <pod-name> --all-containers=true --since=1h

# Get logs with container names prefixed
kubectl logs <pod-name> --all-containers=true --prefix=true
```

## 🐛 Common Debugging Scenarios

### Scenario 1: Container Won't Start
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check container status
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].state}'

# Get detailed container info
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[?(@.name=="<container-name>")].state}'

# Check resource constraints
kubectl describe node <node-name>
```

### Scenario 2: Inter-Container Communication Issues
```bash
# Test network connectivity between containers
kubectl exec -it <pod-name> -c <container1> -- nc -z localhost <port>

# Check listening ports in container
kubectl exec -it <pod-name> -c <container> -- netstat -tlnp

# Test HTTP connectivity
kubectl exec -it <pod-name> -c <container1> -- curl -v http://localhost:<port>

# Check network interfaces
kubectl exec -it <pod-name> -c <container> -- ip addr show
```

### Scenario 3: Volume Mounting Issues
```bash
# Check mounted volumes
kubectl exec -it <pod-name> -c <container> -- df -h

# List volume contents
kubectl exec -it <pod-name> -c <container> -- ls -la /path/to/volume

# Check file permissions
kubectl exec -it <pod-name> -c <container> -- ls -la /path/to/file

# Test file write permissions
kubectl exec -it <pod-name> -c <container> -- touch /path/to/volume/test-file
```

### Scenario 4: Resource Issues
```bash
# Check resource usage
kubectl top pod <pod-name> --containers

# Check resource limits and requests
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources}'

# Monitor resource usage over time
watch kubectl top pod <pod-name> --containers

# Check node resources
kubectl top node
```

## 🔧 Advanced Debugging Techniques

### Network Debugging
```bash
# Create debug pod with network tools
kubectl run netshoot --rm -i --tty --image nicolaka/netshoot -- /bin/bash

# Test DNS resolution
kubectl exec -it <pod-name> -c <container> -- nslookup kubernetes.default

# Check iptables rules (if privileged)
kubectl exec -it <pod-name> -c <container> -- iptables -L

# Trace network packets
kubectl exec -it <pod-name> -c <container> -- tcpdump -i any
```

### Security Context Debugging
```bash
# Check running user and group
kubectl exec -it <pod-name> -c <container> -- id

# Check process list with users
kubectl exec -it <pod-name> -c <container> -- ps aux

# Check file system permissions
kubectl exec -it <pod-name> -c <container> -- ls -la /

# Check capabilities
kubectl exec -it <pod-name> -c <container> -- capsh --print
```

### Configuration Debugging
```bash
# Check environment variables
kubectl exec -it <pod-name> -c <container> -- env

# Check mounted config files
kubectl exec -it <pod-name> -c <container> -- cat /path/to/config

# Verify secrets are mounted correctly
kubectl exec -it <pod-name> -c <container> -- ls -la /var/secrets/

# Check ConfigMap contents
kubectl get configmap <configmap-name> -o yaml
```

## 🚨 Emergency Debugging

### When Pod is CrashLooping
```bash
# Get exit code and reason
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[?(@.name=="<container>")].lastState.terminated}'

# Get previous logs before crash
kubectl logs <pod-name> -c <container> --previous

# Check restart count
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[?(@.name=="<container>")].restartCount}'

# Describe for recent events
kubectl describe pod <pod-name>
```

### When Pod is Stuck in Pending
```bash
# Check scheduling events
kubectl describe pod <pod-name> | grep Events -A 20

# Check node resources
kubectl describe nodes

# Check pod resource requests
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources.requests}'

# Check for node selector issues
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'
```

## 📊 Monitoring and Metrics

### Resource Monitoring
```bash
# Continuous resource monitoring
watch -n 1 kubectl top pod <pod-name> --containers

# Get resource usage history (if metrics-server available)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods/<pod-name>

# Check container resource limits
kubectl get pod <pod-name> -o json | jq '.spec.containers[].resources'
```

### Event Monitoring
```bash
# Watch events in real-time
kubectl get events --watch

# Get events for specific pod
kubectl get events --field-selector involvedObject.name=<pod-name>

# Get events sorted by timestamp
kubectl get events --sort-by='.metadata.creationTimestamp'
```

## 🎯 CKAD Exam-Specific Tips

### Quick Problem Identification
```bash
# One-liner to check all container statuses
kubectl get pod <pod-name> -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.state}{"\n"}{end}'

# Quick health check for multi-container pod
kubectl get pod <pod-name> -o jsonpath='{.status.phase}{"\n"}{range .status.containerStatuses[*]}{.name}: {.ready}{"\n"}{end}'

# Fast log check for errors
kubectl logs <pod-name> -c <container> --tail=50 | grep -i error
```

### Common Fix Patterns
```bash
# Fix volume permission issues
kubectl patch pod <pod-name> -p '{"spec":{"securityContext":{"fsGroup":2000}}}'

# Check if application binds to correct interface
kubectl exec <pod-name> -c <container> -- netstat -tlnp | grep :8080

# Verify shared volume mounts
kubectl get pod <pod-name> -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{range .volumeMounts[*]}{"  "}{.name}{" -> "}{.mountPath}{"\n"}{end}{end}'
```

### Time-Saving Aliases
```bash
# Add these to your shell profile
alias k='kubectl'
alias kgp='kubectl get pods'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kg='kubectl get'

# Multi-container specific aliases
alias klc='kubectl logs -c'  # klc pod-name container-name
alias kexc='kubectl exec -it -c'  # kexc pod-name container-name -- command
```

## 🔍 Troubleshooting Checklist

### For Any Multi-Container Issue:
1. ✅ Check pod status: `kubectl get pod <pod-name>`
2. ✅ Describe pod for events: `kubectl describe pod <pod-name>`
3. ✅ Check logs from all containers: `kubectl logs <pod-name> --all-containers`
4. ✅ Verify container statuses: `kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].name}'`
5. ✅ Test inter-container communication if needed
6. ✅ Check resource usage: `kubectl top pod <pod-name> --containers`
7. ✅ Verify volume mounts and permissions
8. ✅ Check security contexts and capabilities

### For CKAD Exam:
- Practice these commands until they become muscle memory
- Focus on fast problem identification
- Master the most common debugging scenarios
- Use aliases to save time
- Always check the simplest things first (typos, basic connectivity)

---

**Remember**: In the CKAD exam, time is crucial. Master these commands and use them systematically to quickly identify and resolve multi-container issues.