# Kubernetes Container Health Probes - Practical Exercises

This guide contains hands-on exercises to help you practice implementing and troubleshooting Kubernetes container health probes. These exercises are designed to reinforce the concepts covered in the main documentation.

## Prerequisites

- Access to a Kubernetes cluster (local with Minikube, Docker Desktop, or a cloud provider)
- `kubectl` installed and configured to connect to your cluster
- Basic understanding of Kubernetes concepts

## Exercise 1: Implementing HTTP Probes for a Web Application

### Objective
Create a web application pod with appropriate HTTP probes for all three probe types.

### Steps

1. Create a file named `exercise1.yaml` with the following content:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise1-web
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

2. Deploy the pod:

```bash
kubectl apply -f exercise1.yaml
```

3. Verify the pod is running:

```bash
kubectl get pods exercise1-web
```

4. Add appropriate health probes by updating the yaml file:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise1-web
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    # Add your probe definitions here
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
```

5. Apply the updated configuration:

```bash
kubectl replace --force -f exercise1.yaml
```

6. Check the status of the probes:

```bash
kubectl describe pod exercise1-web
```

7. Create a file that will cause the readiness probe to fail:

```bash
# Create a file that can be used to modify nginx configuration to return 500 errors
kubectl exec -it exercise1-web -- bash -c 'echo "server { listen 80; location / { return 500; } }" > /etc/nginx/conf.d/default.conf'

# Reload nginx
kubectl exec -it exercise1-web -- nginx -s reload
```

8. Observe what happens to the pod's ready status:

```bash
kubectl get pods exercise1-web
```

9. Fix the issue and restore readiness:

```bash
kubectl exec -it exercise1-web -- bash -c 'echo "server { listen 80; location / { return 200; } }" > /etc/nginx/conf.d/default.conf'
kubectl exec -it exercise1-web -- nginx -s reload
```

## Exercise 2: Using Exec Probes with a Backend Application

### Objective
Create a pod that uses exec probes to check the application's health by executing commands inside the container.

### Steps

1. Create a file named `exercise2.yaml` with the following content:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise2-backend
spec:
  containers:
  - name: backend
    image: busybox:latest
    command: ["/bin/sh", "-c", "touch /tmp/healthy; sleep infinity"]
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
    readinessProbe:
      exec:
        command:
        - ls
        - /tmp/ready
      initialDelaySeconds: 5
      periodSeconds: 5
```

2. Deploy the pod:

```bash
kubectl apply -f exercise2.yaml
```

3. Check the status of the pod:

```bash
kubectl get pods exercise2-backend
```

4. Note that the pod is running but not ready (check the READY column):

```bash
# Expected output shows 0/1 ready
# NAME               READY   STATUS    RESTARTS   AGE
# exercise2-backend  0/1     Running   0          30s
```

5. Create a file to make the readiness probe pass:

```bash
kubectl exec exercise2-backend -- touch /tmp/ready
```

6. Check that the pod is now ready:

```bash
kubectl get pods exercise2-backend
```

7. Simulate a failure of the liveness probe:

```bash
kubectl exec exercise2-backend -- rm /tmp/healthy
```

8. Wait for the liveness probe to fail and observe the pod being restarted:

```bash
kubectl get pods exercise2-backend
# Watch the RESTARTS column increment
```

9. Verify what happened using the events:

```bash
kubectl describe pod exercise2-backend
# Look for events indicating liveness probe failures and container restarts
```

## Exercise 3: Implementing Startup Probes for Slow-Starting Applications

### Objective
Create a pod with a startup probe to handle a slow-starting application.

### Steps

1. Create a file named `exercise3.yaml` with the following content:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise3-slow-start
spec:
  containers:
  - name: slow-app
    image: busybox:latest
    command: ["/bin/sh", "-c", "echo 'App starting...'; sleep 30; touch /tmp/ready; echo 'App started!'; sleep infinity"]
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      failureThreshold: 10
      periodSeconds: 5
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      periodSeconds: 5
```

2. Deploy the pod:

```bash
kubectl apply -f exercise3.yaml
```

3. Monitor the pod status:

```bash
kubectl get pods exercise3-slow-start -w
```

4. Note how the pod remains in a non-ready state until the startup probe succeeds, after which the liveness probe becomes active.

5. Check the events to see the probe activity:

```bash
kubectl describe pod exercise3-slow-start
```

## Exercise 4: TCP Socket Probes for Database Connectivity

### Objective
Create a MySQL database pod with TCP socket probes to verify connectivity.

### Steps

1. Create a file named `exercise4.yaml` with the following content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  password: cGFzc3dvcmQ=  # "password" in base64
---
apiVersion: v1
kind: Pod
metadata:
  name: exercise4-mysql
spec:
  containers:
  - name: mysql
    image: mysql:5.7
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-secret
          key: password
    ports:
    - containerPort: 3306
    startupProbe:
      tcpSocket:
        port: 3306
      failureThreshold: 30
      periodSeconds: 10
    readinessProbe:
      tcpSocket:
        port: 3306
      initialDelaySeconds: 20
      periodSeconds: 5
```

2. Deploy the pod:

```bash
kubectl apply -f exercise4.yaml
```

3. Monitor the pod status:

```bash
kubectl get pods exercise4-mysql -w
```

4. Once the pod is running and ready, verify that both probes are working:

```bash
kubectl describe pod exercise4-mysql
```

5. You can also test the TCP connectivity manually:

```bash
# Create a temporary pod to test connectivity
kubectl run netcat --rm -it --image=busybox -- sh

# From within the netcat pod, test the MySQL TCP connection
nc -zv exercise4-mysql.default.svc.cluster.local 3306
# Or using the pod IP directly
nc -zv $(kubectl get pod exercise4-mysql -o jsonpath='{.status.podIP}') 3306
```

## Exercise 5: Combined Probes in a Deployment

### Objective
Create a deployment with all three types of probes configured properly.

### Steps

1. Create a file named `exercise5.yaml` with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exercise5-app
  labels:
    app: exercise5
spec:
  replicas: 3
  selector:
    matchLabels:
      app: exercise5
  template:
    metadata:
      labels:
        app: exercise5
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
        startupProbe:
          httpGet:
            path: /
            port: 80
          failureThreshold: 30
          periodSeconds: 2
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: exercise5-service
spec:
  selector:
    app: exercise5
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

2. Deploy the resources:

```bash
kubectl apply -f exercise5.yaml
```

3. Check the deployment status:

```bash
kubectl get deployment exercise5-app
```

4. Check that the pods are running and ready:

```bash
kubectl get pods -l app=exercise5
```

5. Make one pod's readiness probe fail:

```bash
# Get the first pod name
POD_NAME=$(kubectl get pods -l app=exercise5 -o jsonpath='{.items[0].metadata.name}')

# Make the readiness probe fail
kubectl exec $POD_NAME -- bash -c 'echo "server { listen 80; location / { return 500; } }" > /etc/nginx/conf.d/default.conf'
kubectl exec $POD_NAME -- nginx -s reload
```

6. Check what happens to the service endpoints:

```bash
# Check pod readiness
kubectl get pods -l app=exercise5

# Check service endpoints
kubectl describe service exercise5-service
```

7. Fix the readiness probe:

```bash
kubectl exec $POD_NAME -- bash -c 'echo "server { listen 80; location / { return 200; } }" > /etc/nginx/conf.d/default.conf'
kubectl exec $POD_NAME -- nginx -s reload
```

8. Verify that the pod is included in the service endpoints again:

```bash
kubectl describe service exercise5-service
```

## Exercise 6: Using Readiness Gates

### Objective
Create a pod with a custom readiness gate and observe its behavior.

### Steps

1. Create a file named `exercise6.yaml` with the following content:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise6-readiness-gate
spec:
  readinessGates:
  - conditionType: "example.com/custom-condition"
  containers:
  - name: app
    image: nginx:latest
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
```

2. Deploy the pod:

```bash
kubectl apply -f exercise6.yaml
```

3. Check the pod status:

```bash
kubectl get pod exercise6-readiness-gate -o wide
```

4. Note that even though the container readiness probe succeeds, the pod is not marked as ready because the readiness gate condition is not satisfied:

```bash
kubectl get pod exercise6-readiness-gate -o jsonpath='{.status.conditions}' | jq
```

5. In a real scenario, an external controller would update the pod status to satisfy the readiness gate. Since we don't have that, we can observe the behavior:

```bash
kubectl describe pod exercise6-readiness-gate
```

6. Clean up the pod:

```bash
kubectl delete pod exercise6-readiness-gate
```

## Conclusion

These exercises have given you hands-on experience with implementing and testing Kubernetes container health probes. Practice these concepts to become proficient in using probes to improve application reliability in Kubernetes.

Remember these key points:
- Use startup probes for applications with variable startup times
- Implement liveness probes to detect when applications need to be restarted
- Configure readiness probes to manage traffic and service availability
- Choose the appropriate probe mechanism (HTTP, TCP, or exec) based on your application
- Set realistic thresholds and timing values based on your application's behavior
