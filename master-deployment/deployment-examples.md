# Kubernetes Deployment Examples and Hands-on Practice

This document provides practical examples of Kubernetes Deployments to complement the theoretical knowledge in the Master Deployment Guide. These examples are designed to help you prepare for the CKAD exam.

## Basic Deployment Example

Here's a complete example of a basic Deployment manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
```

Apply this deployment:

```bash
kubectl apply -f nginx-deployment.yaml
```

## Rolling Update Example

This example shows how to configure a Deployment with a specific rolling update strategy:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 5
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend:v1
        ports:
        - containerPort: 80
```

## Deployment with Environment Variables

This example shows how to configure environment variables in a Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: backend:v1
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgres://user:password@postgres:5432/db"
        - name: API_KEY
          value: "your-api-key"
        - name: DEBUG_MODE
          value: "false"
```

## Deployment with ConfigMap

First, create a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://user:password@postgres:5432/db"
  api_url: "https://api.example.com"
  log_level: "info"
```

Then reference it in the Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  labels:
    app: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v1
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_url
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: api_url
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
```

## Deployment with Secrets

First, create a Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db_password: cGFzc3dvcmQxMjM=  # base64 encoded "password123"
  api_key: dGhpc2lzYXNlY3JldGtleQ==  # base64 encoded "thisisasecretkey"
```

Then reference it in the Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  labels:
    app: secure-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: secure-app
        image: secure-app:v1
        ports:
        - containerPort: 8443
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: api_key
```

## Deployment with Resource Limits

This example shows how to set resource limits and requests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-limited-app
  labels:
    app: resource-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: resource-app
  template:
    metadata:
      labels:
        app: resource-app
    spec:
      containers:
      - name: resource-app
        image: resource-app:v1
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
          requests:
            cpu: "500m"
            memory: "256Mi"
        ports:
        - containerPort: 8080
```

## Multi-Container Deployment

This example shows a Deployment with multiple containers in a Pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-container-app
  labels:
    app: multi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-app
  template:
    metadata:
      labels:
        app: multi-app
    spec:
      containers:
      - name: web
        image: nginx:1.14.2
        ports:
        - containerPort: 80
      - name: log-collector
        image: fluentd:v1.11
        volumeMounts:
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: logs
        emptyDir: {}
```

## Deployment with Init Containers

This example demonstrates using init containers to perform setup tasks:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-init
  labels:
    app: init-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: init-app
  template:
    metadata:
      labels:
        app: init-app
    spec:
      initContainers:
      - name: init-db-check
        image: busybox:1.28
        command: ['sh', '-c', 'until nslookup mysql; do echo waiting for mysql; sleep 2; done;']
      containers:
      - name: app
        image: app:v1
        ports:
        - containerPort: 80
```

## Practical Exercises

### Exercise 1: Create and Scale a Deployment

1. Create a Deployment with 2 replicas of the `nginx` image
   ```bash
   kubectl create deployment nginx-test --image=nginx --replicas=2
   ```

2. Verify the Deployment is running
   ```bash
   kubectl get deployments
   kubectl get pods
   ```

3. Scale the Deployment to 5 replicas
   ```bash
   kubectl scale deployment nginx-test --replicas=5
   ```

4. Verify the scaling was successful
   ```bash
   kubectl get pods
   ```

### Exercise 2: Update a Deployment

1. Create a Deployment with the `nginx:1.14.2` image
   ```bash
   kubectl create deployment nginx-update --image=nginx:1.14.2
   ```

2. Update the Deployment to use `nginx:1.19.0`
   ```bash
   kubectl set image deployment/nginx-update nginx-update=nginx:1.19.0
   ```

3. Check the rollout status
   ```bash
   kubectl rollout status deployment/nginx-update
   ```

4. View the rollout history
   ```bash
   kubectl rollout history deployment/nginx-update
   ```

### Exercise 3: Roll Back a Deployment

1. Update the Deployment with an invalid image
   ```bash
   kubectl set image deployment/nginx-update nginx-update=nginx:invalid_tag
   ```

2. Observe the rollout status (it will fail)
   ```bash
   kubectl rollout status deployment/nginx-update
   ```

3. Roll back to the previous version
   ```bash
   kubectl rollout undo deployment/nginx-update
   ```

4. Verify the rollback was successful
   ```bash
   kubectl get pods
   kubectl describe deployment nginx-update
   ```

### Exercise 4: Create a Deployment from a YAML File

1. Generate a YAML file for a Deployment
   ```bash
   kubectl create deployment yaml-demo --image=nginx --dry-run=client -o yaml > yaml-demo.yaml
   ```

2. Edit the YAML file to add resource limits and labels

3. Apply the modified YAML file
   ```bash
   kubectl apply -f yaml-demo.yaml
   ```

### Exercise 5: Configure a Deployment with Environment Variables

1. Create a Deployment with environment variables
   ```bash
   kubectl create deployment env-demo --image=nginx --dry-run=client -o yaml > env-demo.yaml
   ```

2. Edit the YAML file to add environment variables:
   ```yaml
   spec:
     template:
       spec:
         containers:
         - name: env-demo
           image: nginx
           env:
           - name: APP_ENV
             value: "production"
           - name: LOG_LEVEL
             value: "info"
   ```

3. Apply the Deployment
   ```bash
   kubectl apply -f env-demo.yaml
   ```

4. Verify the environment variables
   ```bash
   kubectl exec -it $(kubectl get pods -l app=env-demo -o jsonpath="{.items[0].metadata.name}") -- env | grep APP_ENV
   ```

## CKAD Exam Tips

1. **Use kubectl short commands** to save time during the exam:
   - `kubectl get deployments` can be shortened to `kubectl get deploy`
   - `kubectl describe deployment` can be shortened to `kubectl describe deploy`

2. **Use imperative commands** for simple tasks:
   - Creating a deployment: `kubectl create deployment name --image=image`
   - Scaling a deployment: `kubectl scale deployment name --replicas=3`

3. **Use dry-run to generate YAML templates**:
   ```bash
   kubectl create deployment name --image=image --dry-run=client -o yaml > deployment.yaml
   ```

4. **Common update commands**:
   - Update image: `kubectl set image deployment/name container=image:tag`
   - Scale deployment: `kubectl scale deployment name --replicas=3`
   - Edit deployment: `kubectl edit deployment name`

5. **Check deployment status**:
   - Deployment status: `kubectl rollout status deployment/name`
   - Rollout history: `kubectl rollout history deployment/name`
   - Undo rollout: `kubectl rollout undo deployment/name`

By practicing these examples and exercises, you'll be well-prepared for the Deployment-related questions in the CKAD exam.