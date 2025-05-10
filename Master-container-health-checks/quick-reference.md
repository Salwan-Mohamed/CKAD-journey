# Kubernetes Container Health Probes - Quick Reference

## Probe Types

| Type | Purpose | When it runs | Failure Behavior |
|------|---------|--------------|------------------|
| **Startup Probe** | Determines when app has initialized | During init phase only | Container restarts after failureThreshold |
| **Liveness Probe** | Detects if container is running correctly | Throughout lifecycle after startup | Container restarts |
| **Readiness Probe** | Checks if container can serve traffic | Throughout lifecycle | Container removed from service endpoints |

## Probe Mechanisms

| Mechanism | How it works | Success criteria | Example |
|-----------|-------------|------------------|---------|
| **HTTP GET** | Sends HTTP GET request | 200-399 status code | `httpGet: {path: "/healthz", port: 8080}` |
| **TCP Socket** | Opens TCP connection | Connection established | `tcpSocket: {port: 3306}` |
| **Exec** | Runs command in container | Exit code 0 | `exec: {command: ["cat", "/tmp/healthy"]}` |

## Common Parameters

| Parameter | Description | Default | Example Value |
|-----------|-------------|---------|---------------|
| `initialDelaySeconds` | Wait time after container starts | 0 | `30` |
| `periodSeconds` | How often to check | 10 | `5` |
| `timeoutSeconds` | How long to wait for response | 1 | `3` |
| `successThreshold` | Consecutive successes needed | 1 | `1` |
| `failureThreshold` | Consecutive failures before action | 3 | `5` |

## Quick Formulas

- **Maximum startup time allowed** = `failureThreshold × periodSeconds`
  - Example: 30 × 10 = 300 seconds (5 minutes)

- **Probe frequency** = Every `periodSeconds` seconds
  - Example: Every 5 seconds

- **Time before first check** = `initialDelaySeconds` after container starts
  - Example: 30 seconds after container starts

## Common Pod Conditions

| Condition | Meaning | Affected By |
|-----------|---------|-------------|
| `PodScheduled` | Pod assigned to a node | Scheduler |
| `Initialized` | Init containers completed | Init container success |
| `ContainersReady` | All containers ready | Container readiness probes |
| `Ready` | Pod can serve traffic | Container readiness + readiness gates |

## Common YAML Snippets

### HTTP Probe Example

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

### TCP Socket Probe Example

```yaml
readinessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 5
  periodSeconds: 10
```

### Exec Probe Example

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Startup Probe Example

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

### All Three Probes Together

```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 3
```

### Readiness Gate Example

```yaml
readinessGates:
- conditionType: "www.example.com/feature-1"
```

## Essential Commands

```bash
# View pod status
kubectl get pods

# Check probe configuration
kubectl describe pod <pod-name>

# View detailed conditions
kubectl get pod <pod-name> -o json | jq '.status.conditions'

# Check container logs
kubectl logs <pod-name>

# Check events
kubectl get events --field-selector involvedObject.name=<pod-name>

# Test HTTP endpoint manually
kubectl exec <pod-name> -- curl -v http://localhost:8080/healthz

# Test TCP connection manually
kubectl exec <pod-name> -- nc -zv localhost 3306

# Create/remove file for exec probe testing
kubectl exec <pod-name> -- touch /tmp/healthy
kubectl exec <pod-name> -- rm /tmp/healthy
```

## CKAD Exam Tips

1. **Know these basic templates** to save time during the exam
2. **Use appropriate probe types**:
   - Startup probes for slow-starting apps
   - Liveness probes for detecting crash/deadlock
   - Readiness probes for handling dependencies
3. **Choose the right mechanism**:
   - HTTP for web apps and APIs
   - TCP for databases and network services
   - Exec for custom checks and scripts
4. **Set realistic timeouts**:
   - Consider application's normal response time
   - Be generous with initialDelaySeconds
5. **Remember the defaults**:
   - initialDelaySeconds: 0
   - periodSeconds: 10
   - timeoutSeconds: 1
   - successThreshold: 1
   - failureThreshold: 3
