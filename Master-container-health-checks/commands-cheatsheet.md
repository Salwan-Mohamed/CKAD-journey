# Kubernetes Container Health Checks - Commands Cheatsheet

This cheatsheet provides essential commands for working with Kubernetes container health probes.

## Checking Pod Status

```bash
# Get basic pod status including readiness
kubectl get pods

# Output includes columns:
# NAME                READY   STATUS    RESTARTS   AGE
# web-application     1/1     Running   0          5m
```

The `READY` column shows how many containers in the pod are ready compared to the total containers.

## Getting Detailed Pod Information

```bash
# Get detailed pod information including probe status
kubectl describe pod <pod-name>

# Example output section:
#    Container ID:   containerd://b5d9...
#    Ports:          80/TCP, 443/TCP
#    ...
#    
#    Liveness:       http-get http://:80/healthz delay=10s timeout=1s period=5s #success=1 #failure=3
#    Readiness:      http-get http://:80/ready delay=5s timeout=1s period=3s #success=1 #failure=3
#    Startup:        http-get http://:80/startup delay=0s timeout=1s period=2s #success=1 #failure=30
#    
#    Last State:     Terminated
#      Reason:       Error
#      Message:      container failed liveness probe, will be restarted
```

## Viewing Detailed Status Conditions

```bash
# View detailed status conditions in JSON format
kubectl get pod <pod-name> -o json | jq '.status.conditions'

# Example output:
# [
#   {
#     "lastProbeTime": null,
#     "lastTransitionTime": "2023-05-10T12:34:56Z",
#     "status": "True",
#     "type": "Initialized"
#   },
#   {
#     "lastProbeTime": null,
#     "lastTransitionTime": "2023-05-10T12:35:23Z",
#     "status": "True",
#     "type": "Ready"
#   },
#   {
#     "lastProbeTime": null,
#     "lastTransitionTime": "2023-05-10T12:35:23Z",
#     "status": "True",
#     "type": "ContainersReady"
#   },
#   {
#     "lastProbeTime": null,
#     "lastTransitionTime": "2023-05-10T12:34:56Z",
#     "status": "True",
#     "type": "PodScheduled"
#   }
# ]
```

## Checking Container Logs

```bash
# Check container logs for probe-related issues
kubectl logs <pod-name>

# For multi-container pods, specify the container
kubectl logs <pod-name> -c <container-name>

# Follow logs in real-time
kubectl logs <pod-name> -f
```

## Getting Events Related to Probes

```bash
# Get events sorted by timestamp
kubectl get events --sort-by=.metadata.creationTimestamp

# Filter events related to a specific pod
kubectl get events --field-selector involvedObject.name=<pod-name>
```

## Checking Readiness Gates

```bash
# Check if custom readiness gates are satisfied
kubectl get pod <pod-name> -o json | jq '.status.conditions[] | select(.type=="www.example.com/feature-1")'
```

## Simulating Probe Failures for Testing

```bash
# Create a temporary file to make a readiness probe fail
kubectl exec <pod-name> -- touch /tmp/maintenance

# Remove the file to restore readiness
kubectl exec <pod-name> -- rm /tmp/maintenance

# Temporarily disable a service endpoint (for HTTP probes)
kubectl exec <pod-name> -- mv /usr/share/nginx/html/healthz /usr/share/nginx/html/healthz.bak

# Restore the service endpoint
kubectl exec <pod-name> -- mv /usr/share/nginx/html/healthz.bak /usr/share/nginx/html/healthz
```

## Viewing Pod IP and Port for Manual Probe Testing

```bash
# Get the pod IP address
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')

# For manual probe testing from another pod
kubectl exec <testing-pod> -- curl -v http://$POD_IP:80/healthz
```

## Editing Probe Configuration on Running Pods

```bash
# Edit a pod's configuration (note: some fields cannot be updated after creation)
kubectl edit pod <pod-name>

# Alternative: replace the pod with an updated definition
kubectl replace --force -f updated-pod.yaml
```

Remember that most probe settings cannot be updated on a running pod. You'll typically need to recreate the pod with the new configuration.
