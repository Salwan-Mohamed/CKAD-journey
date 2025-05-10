# Troubleshooting Kubernetes Health Probes

This guide provides solutions for common issues encountered with Kubernetes container health probes.

## Diagnostic Commands

Always start your troubleshooting with these commands:

```bash
# Get basic pod status
kubectl get pod <pod-name>

# Get detailed pod information, including probe configuration and events
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# View pod events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

## Common Issues and Solutions

### 1. Container Restarts in a Loop

**Symptoms:**
- Pod shows high restart count
- Pod status cycles between `Running` and `CrashLoopBackOff`

**Possible Causes:**
- Liveness probe is too strict or improperly configured
- Application temporarily fails during startup but probe starts checking too early
- Resource constraints causing application timeouts during probe checks

**Solutions:**

1. **Check probe configuration:**
   ```bash
   kubectl describe pod <pod-name> | grep -A 15 "Liveness:"
   ```

2. **Increase liveness probe tolerance:**
   ```yaml
   livenessProbe:
     # Increase these values
     initialDelaySeconds: 30    # Give app more time to start
     periodSeconds: 10          # Check less frequently
     timeoutSeconds: 5          # Allow more time for response
     failureThreshold: 3        # Allow more failures before restart
   ```

3. **Examine container logs for errors during probe checks:**
   ```bash
   kubectl logs <pod-name> --previous
   ```

4. **Check if application has sufficient resources:**
   ```bash
   kubectl describe pod <pod-name> | grep -A 10 "Limits:"
   ```

5. **Implement a startup probe** to give the application time to initialize before liveness checks begin:
   ```yaml
   startupProbe:
     httpGet:
       path: /healthz
       port: 8080
     failureThreshold: 30
     periodSeconds: 10
   ```

### 2. Pod Running but Not Ready

**Symptoms:**
- Pod shows `Running` status but READY column shows `0/1`
- Service does not route traffic to the pod

**Possible Causes:**
- Readiness probe is failing
- Application is not properly serving the readiness endpoint
- External dependencies required by readiness check are unavailable

**Solutions:**

1. **Check readiness probe status:**
   ```bash
   kubectl describe pod <pod-name> | grep -A 15 "Readiness:"
   ```

2. **Test the readiness endpoint manually:**
   ```bash
   # Get pod IP
   POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
   
   # For HTTP probes - create a test pod
   kubectl run test --rm -it --image=curlimages/curl -- curl -v http://$POD_IP:8080/ready
   
   # For TCP probes - create a test pod
   kubectl run test --rm -it --image=busybox -- nc -zv $POD_IP 3306
   ```

3. **Check application logs for readiness issues:**
   ```bash
   kubectl logs <pod-name> | grep -i ready
   ```

4. **Verify external dependencies are available** (databases, APIs, other services)

5. **Modify readiness probe parameters** to be more tolerant:
   ```yaml
   readinessProbe:
     periodSeconds: 10          # Check less frequently 
     timeoutSeconds: 5          # Allow more time for response
     failureThreshold: 3        # Allow more failures before marking not ready
   ```

### 3. Probes Passing Locally but Failing in Kubernetes

**Symptoms:**
- Application works when tested directly but fails when accessed via Kubernetes probes
- Probe failure messages in `kubectl describe pod` output

**Possible Causes:**
- Network path differences between local testing and Kubernetes
- Different port or path configurations
- Kubernetes probe timeout too short for application response time

**Solutions:**

1. **Verify probe endpoint configuration:**
   ```bash
   kubectl describe pod <pod-name> | grep -A 15 "Liveness\|Readiness\|Startup"
   ```

2. **Test exact probe path from inside the container:**
   ```bash
   kubectl exec <pod-name> -- curl -v http://localhost:<port>/<path>
   ```

3. **Check for network policy restrictions** that might block probe requests

4. **Increase probe timeout:**
   ```yaml
   livenessProbe:
     timeoutSeconds: 5  # Increase from default 1s to 5s
   ```

5. **Check for port binding issues** - ensure app is listening on 0.0.0.0, not just 127.0.0.1

### 4. Intermittent Probe Failures

**Symptoms:**
- Pod occasionally shows not ready then becomes ready again
- Logs show sporadic restarts due to probe failures
- Service endpoints fluctuate

**Possible Causes:**
- Application occasionally takes too long to respond
- Resource contention affecting response times
- Garbage collection or maintenance routines disrupting probes
- Network instability

**Solutions:**

1. **Check if failures correlate with high load periods:**
   ```bash
   kubectl top pod <pod-name>
   ```

2. **Make probe parameters more tolerant:**
   ```yaml
   livenessProbe:
     # Increase these values
     periodSeconds: 15          # Check less frequently
     timeoutSeconds: 10         # Allow more time for response
     failureThreshold: 5        # Require more consecutive failures
   ```

3. **Look for patterns in failures** (time of day, load patterns, etc.)

4. **Check node resources** where the pod is running:
   ```bash
   kubectl describe node <node-name>
   ```

5. **Add a startup probe** with generous thresholds:
   ```yaml
   startupProbe:
     httpGet:
       path: /healthz
       port: 8080
     failureThreshold: 30       # 30 * 10s = 5 minutes to start
     periodSeconds: 10
   ```

### 5. HTTP Probe Returns Unexpected Status Codes

**Symptoms:**
- HTTP probe failures in logs
- Pod health fluctuates despite application appearing to work

**Possible Causes:**
- Application returns non-2xx status codes
- Health endpoint returning unexpected responses
- Redirects causing probe failures (3xx status codes not handling properly)

**Solutions:**

1. **Test endpoint manually:**
   ```bash
   kubectl exec <pod-name> -- curl -v http://localhost:<port>/<path>
   ```

2. **Check endpoint response code:**
   ```bash
   kubectl exec <pod-name> -- curl -I http://localhost:<port>/<path>
   ```

3. **Configure probe to accept specific status codes:**
   ```yaml
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
       httpHeaders:
       - name: Accept
         value: application/json
   ```

4. **Ensure health endpoint returns appropriate status code** (200-399 for success)

5. **Check if endpoint is redirecting** (301/302/307) as this can cause issues

### 6. Slow Application Startup Causing Premature Failures

**Symptoms:**
- Pod repeatedly restarts before becoming ready
- Events show liveness or readiness probe failure during initialization

**Possible Causes:**
- Application initialization time exceeds probe's initialDelaySeconds
- Insufficient startup probe configuration
- Heavy initialization workloads (DB migrations, cache warming)

**Solutions:**

1. **Add a startup probe** (Kubernetes 1.16+):
   ```yaml
   startupProbe:
     httpGet:
       path: /healthz
       port: 8080
     failureThreshold: 30
     periodSeconds: 10
   ```

2. **Increase initialDelaySeconds** for both probes:
   ```yaml
   livenessProbe:
     initialDelaySeconds: 120  # Increase to 2 minutes
   readinessProbe:
     initialDelaySeconds: 30   # Increase to 30 seconds
   ```

3. **For very slow starting apps**, calculate proper thresholds:
   ```
   Maximum startup time = failureThreshold × periodSeconds
   ```

4. **Consider optimizing application startup** time if practical

### 7. Issues with Exec Probes

**Symptoms:**
- Exec probe failures despite application running
- Permission denied or command not found errors

**Possible Causes:**
- Script/command not executable
- Path issues within container
- Permission problems
- Command timeout

**Solutions:**

1. **Verify command exists and is executable:**
   ```bash
   kubectl exec <pod-name> -- ls -la /path/to/script
   ```

2. **Test command execution manually:**
   ```bash
   kubectl exec <pod-name> -- /path/to/command
   ```

3. **Check for permission issues:**
   ```bash
   kubectl exec <pod-name> -- chmod +x /path/to/script
   ```

4. **Use shell for complex commands:**
   ```yaml
   livenessProbe:
     exec:
       command:
       - /bin/sh
       - -c
       - "test -f /tmp/healthy || exit 1"
   ```

5. **Increase timeoutSeconds if command takes too long**

### 8. TCP Socket Probe Failures

**Symptoms:**
- TCP socket connection failures
- Service appears to be running but probe fails

**Possible Causes:**
- Application not listening on specified port
- Firewall or network policy restrictions
- Socket backlog full

**Solutions:**

1. **Verify service is listening on the correct port:**
   ```bash
   kubectl exec <pod-name> -- netstat -tlnp
   ```

2. **Check for port binding restrictions** (make sure app binds to 0.0.0.0, not just 127.0.0.1)

3. **Test TCP connection manually:**
   ```bash
   kubectl exec <pod-name> -- nc -zv localhost <port>
   ```

4. **Check for any NetworkPolicy restrictions**

5. **Examine application logs for socket/binding errors**

## Advanced Troubleshooting

### Debugging with Ephemeral Containers (Kubernetes 1.18+)

For complex cases, ephemeral debug containers can be useful:

```bash
# Start debug container (requires Kubernetes 1.18+ with feature enabled)
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# From the debug container, you can test network connections, check processes, etc.
wget -O- http://localhost:8080/healthz
netstat -tlnp
ps aux
```

### Analyzing Probe Traffic with tcpdump

For network-related issues:

```bash
# Create a privileged debug pod
kubectl run debug-pod --privileged --rm -it --image=nicolaka/netshoot -- bash

# Install tcpdump if needed
apt-get update && apt-get install -y tcpdump

# Capture probe traffic
tcpdump -i eth0 port <probe-port> -vvv
```

### Detailed Probe Timing Analysis

For performance-related problems:

```bash
# Get probe timing details
kubectl get pod <pod-name> -o json | jq '.status.conditions[] | select(.type=="Ready")'

# Check kubelet logs for probe details (on the node)
journalctl -u kubelet | grep <pod-name> | grep -i probe
```

## Preventative Measures

1. **Start with application-appropriate probe settings:**
   - Use startup probes for slow-starting applications
   - Set initialDelaySeconds based on realistic startup time
   - Configure periodSeconds and timeoutSeconds based on expected response times

2. **Implement dedicated lightweight health endpoints** that:
   - Check minimal dependencies
   - Respond quickly
   - Have minimal resource requirements
   - Return appropriate status codes

3. **Test probe behavior under load** before deploying to production

4. **Document normal application behavior** to make troubleshooting easier

## CKAD Exam Tips

For the CKAD exam, remember these troubleshooting tips:

1. Always check pod status with `kubectl get pods` first
2. Use `kubectl describe pod <pod-name>` to see probe configuration and recent events
3. Check logs with `kubectl logs <pod-name>`
4. Know how to adjust probe parameters for common issues:
   - Increase `initialDelaySeconds` for slow-starting applications
   - Adjust `periodSeconds` and `timeoutSeconds` for slow-responding apps
   - Use `failureThreshold` to control tolerance for intermittent failures
5. Know when to use each probe type and mechanism
6. Be able to quickly diagnose if a probe failure is due to:
   - Misconfiguration
   - Application issues
   - Resource constraints
   - Network problems

Remember that solving probe issues often requires a systematic approach of: check configuration → test manually → adjust parameters → verify solution.
