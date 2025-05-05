# Kubernetes Deployment YAML Examples

This file contains ready-to-use YAML examples for different types of Deployment configurations. These examples are designed to help you prepare for the CKAD exam and serve as templates for your own applications.

## Basic Deployment

A simple Deployment with three replicas of nginx:

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
```

## Deployment with Resource Limits

Includes CPU and memory requests and limits:

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

## Deployment with RollingUpdate Strategy

Explicitly configures the rolling update strategy:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-update-app
  labels:
    app: rolling-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: rolling-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: rolling-app
    spec:
      containers:
      - name: rolling-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

## Deployment with Recreate Strategy

Uses the Recreate strategy for updates:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-app
  labels:
    app: recreate-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: recreate-app
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: recreate-app
    spec:
      containers:
      - name: recreate-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

## Deployment with Environment Variables

Includes hardcoded environment variables:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: env-app
  labels:
    app: env-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: env-app
  template:
    metadata:
      labels:
        app: env-app
    spec:
      containers:
      - name: env-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        env:
        - name: DATABASE_URL
          value: "postgres://user:password@postgres:5432/db"
        - name: API_KEY
          value: "your-api-key"
        - name: DEBUG_MODE
          value: "false"
```

## Deployment with ConfigMap Reference

References environment variables from a ConfigMap:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-app
  labels:
    app: configmap-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: configmap-app
  template:
    metadata:
      labels:
        app: configmap-app
    spec:
      containers:
      - name: configmap-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
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
```

Example ConfigMap:

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

## Deployment with Secret Reference

References sensitive data from a Secret:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-app
  labels:
    app: secret-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secret-app
  template:
    metadata:
      labels:
        app: secret-app
    spec:
      containers:
      - name: secret-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
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

Example Secret:

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

## Deployment with Volume Mounts

Mounts a ConfigMap as a volume:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: volume-app
  labels:
    app: volume-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: volume-app
  template:
    metadata:
      labels:
        app: volume-app
    spec:
      containers:
      - name: volume-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: app-config
```

## Deployment with Health Checks

Includes readiness and liveness probes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-app
  labels:
    app: probe-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: probe-app
  template:
    metadata:
      labels:
        app: probe-app
    spec:
      containers:
      - name: probe-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
```

## Multi-Container Deployment

Contains multiple containers in a Pod:

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
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
      - name: log-collector
        image: busybox
        command: ["/bin/sh", "-c", "tail -f /var/log/nginx/access.log"]
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
      volumes:
      - name: shared-logs
        emptyDir: {}
```

## Deployment with Init Containers

Uses an init container to perform setup tasks:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: init-app
  labels:
    app: init-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: init-app
  template:
    metadata:
      labels:
        app: init-app
    spec:
      initContainers:
      - name: init-myservice
        image: busybox:1.28
        command: ['sh', '-c', 'until nslookup myservice.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for myservice; sleep 2; done;']
      containers:
      - name: init-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

## Deployment with Node Selector

Schedules Pods on specific nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-selector-app
  labels:
    app: node-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: node-app
  template:
    metadata:
      labels:
        app: node-app
    spec:
      nodeSelector:
        disktype: ssd
      containers:
      - name: node-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

## Deployment with Annotations

Includes annotations for documentation or integration with other tools:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: annotated-app
  labels:
    app: annotated-app
  annotations:
    deployment.kubernetes.io/revision: "1"
    kubernetes.io/change-cause: "Initial deployment"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: annotated-app
  template:
    metadata:
      labels:
        app: annotated-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
    spec:
      containers:
      - name: annotated-app
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

## Blue-Green Deployment Example

This is more of a pattern than a single resource, but here are the components:

Blue Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-blue
  labels:
    app: my-app
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: blue
  template:
    metadata:
      labels:
        app: my-app
        version: blue
    spec:
      containers:
      - name: my-app
        image: my-app:1.0.0
        ports:
        - containerPort: 8080
```

Green Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-green
  labels:
    app: my-app
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: green
  template:
    metadata:
      labels:
        app: my-app
        version: green
    spec:
      containers:
      - name: my-app
        image: my-app:2.0.0
        ports:
        - containerPort: 8080
```

Service (initially pointing to blue):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
    version: blue
  ports:
  - port: 80
    targetPort: 8080
```