# Practical Exercises: ConfigMaps and Secrets

In this section, we'll work through a series of practical exercises that simulate real-world scenarios and CKAD exam-style questions. These exercises will help you solidify your understanding of ConfigMaps and Secrets in Kubernetes.

## Exercise 1: Basic ConfigMap Creation and Usage

**Scenario**: You're deploying a web application that needs configuration for different environments. Create a ConfigMap for the development environment and use it in a Pod.

**Tasks**:

1. Create a ConfigMap named `web-config-dev` with the following key-value pairs:
   - `environment`: `development`
   - `log_level`: `debug`
   - `db_host`: `dev-db.example.com`

2. Create a ConfigMap named `web-config-dev-files` from the following files:
   - A file named `nginx.conf` with basic Nginx configuration
   - A file named `app.properties` with application properties

3. Create a Pod that uses both ConfigMaps:
   - Use the first ConfigMap as environment variables
   - Mount the second ConfigMap as a volume at `/etc/config`

**Solution**:

```bash
# Step 1: Create ConfigMap with literal values
cat << EOF > web-config-dev.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config-dev
data:
  environment: development
  log_level: debug
  db_host: dev-db.example.com
EOF

kubectl apply -f web-config-dev.yaml

# Alternatively, use the imperative approach
kubectl create configmap web-config-dev \
  --from-literal=environment=development \
  --from-literal=log_level=debug \
  --from-literal=db_host=dev-db.example.com

# Step 2: Create files for the second ConfigMap
mkdir -p config-files
cat << EOF > config-files/nginx.conf
server {
  listen 80;
  server_name example.com;
  
  location / {
    root /usr/share/nginx/html;
    index index.html;
  }
}
EOF

cat << EOF > config-files/app.properties
app.name=MyWebApp
app.version=1.0.0
app.environment=development
app.log.level=debug
EOF

# Create ConfigMap from files
kubectl create configmap web-config-dev-files \
  --from-file=config-files/nginx.conf \
  --from-file=config-files/app.properties

# Step 3: Create Pod using both ConfigMaps
cat << EOF > web-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: web-app
    image: nginx:1.19
    env:
    - name: ENVIRONMENT
      valueFrom:
        configMapKeyRef:
          name: web-config-dev
          key: environment
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: web-config-dev
          key: log_level
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: web-config-dev
          key: db_host
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: web-config-dev-files
EOF

kubectl apply -f web-pod.yaml
```

**Verification**:

```bash
# Verify the Pod is running
kubectl get pod web-app

# Verify environment variables
kubectl exec web-app -- env | grep -E 'ENVIRONMENT|LOG_LEVEL|DB_HOST'

# Verify mounted files
kubectl exec web-app -- ls -l /etc/config
kubectl exec web-app -- cat /etc/config/nginx.conf
kubectl exec web-app -- cat /etc/config/app.properties
```

## Exercise 2: Working with Secrets

**Scenario**: Your application needs to connect to a database using credentials and also needs a TLS certificate for secure communication.

**Tasks**:

1. Create a Secret named `db-credentials` with username and password.
2. Create a TLS Secret named `app-tls` from provided certificate and key files.
3. Create a Pod that uses both Secrets:
   - Use the database credentials as environment variables
   - Mount the TLS certificate and key as files at `/etc/tls`

**Solution**:

```bash
# Step 1: Create Secret with database credentials
cat << EOF > db-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: S3cr3tP@ssw0rd
EOF

kubectl apply -f db-credentials.yaml

# Alternatively, use the imperative approach
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=S3cr3tP@ssw0rd

# Step 2: Generate self-signed certificate for demonstration
# In a real scenario, you'd use your actual certificate and key
mkdir -p tls-certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls-certs/tls.key -out tls-certs/tls.crt \
  -subj "/CN=example.com"

# Create TLS Secret
kubectl create secret tls app-tls \
  --cert=tls-certs/tls.crt \
  --key=tls-certs/tls.key

# Step 3: Create Pod using both Secrets
cat << EOF > secure-app-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  containers:
  - name: app
    image: nginx:1.19
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls-certs
    secret:
      secretName: app-tls
      defaultMode: 0400  # Read-only for owner
EOF

kubectl apply -f secure-app-pod.yaml
```

**Verification**:

```bash
# Verify the Pod is running
kubectl get pod secure-app

# Verify environment variables (notice that we don't print the values for security)
kubectl exec secure-app -- env | grep DB_

# Verify mounted files
kubectl exec secure-app -- ls -l /etc/tls
```

## Exercise 3: ConfigMap Updates and Immutability

**Scenario**: You need to update a ConfigMap and observe how the changes affect a running Pod. Then, make the ConfigMap immutable to prevent accidental changes.

**Tasks**:

1. Create a ConfigMap named `app-config` with a key `config.json`.
2. Create a Pod that mounts this ConfigMap as a volume.
3. Update the ConfigMap and observe how long it takes for the changes to be reflected in the Pod.
4. Make the ConfigMap immutable and verify you can't update it anymore.

**Solution**:

```bash
# Step 1: Create initial ConfigMap
cat << EOF > config.json
{
  "appName": "MyApp",
  "version": "1.0.0",
  "environment": "staging",
  "features": {
    "featureA": true,
    "featureB": false
  }
}
EOF

kubectl create configmap app-config --from-file=config.json

# Step 2: Create Pod with ConfigMap mounted
cat << EOF > config-app-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "while true; do cat /etc/config/config.json; sleep 10; done"]
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
EOF

kubectl apply -f config-app-pod.yaml

# Step 3: Update the ConfigMap
cat << EOF > config-updated.json
{
  "appName": "MyApp",
  "version": "1.0.1",
  "environment": "staging",
  "features": {
    "featureA": true,
    "featureB": true,
    "featureC": true
  }
}
EOF

kubectl create configmap app-config --from-file=config.json=config-updated.json --dry-run=client -o yaml | kubectl apply -f -

# Wait and check logs to see when the update is reflected
# It may take up to 60 seconds for the changes to propagate
kubectl logs -f config-app

# Step 4: Make the ConfigMap immutable
kubectl get configmap app-config -o yaml > app-config-immutable.yaml

# Edit the file to add immutable: true
# Alternatively, use sed to add it:
sed -i '/kind: ConfigMap/a immutable: true' app-config-immutable.yaml

kubectl apply -f app-config-immutable.yaml

# Try to update the immutable ConfigMap (this should fail)
kubectl create configmap app-config --from-file=config.json --dry-run=client -o yaml | kubectl apply -f -
```

## Exercise 4: Projected Volumes

**Scenario**: You need to create a Pod that combines configuration from multiple sources into a single directory.

**Tasks**:

1. Create a ConfigMap named `app-settings` with application settings.
2. Create a Secret named `app-secrets` with sensitive configuration.
3. Create a Pod with a projected volume that combines:
   - The ConfigMap
   - The Secret
   - Downward API information (Pod name and namespace)

**Solution**:

```bash
# Step 1: Create ConfigMap
cat << EOF > app-settings.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  settings.conf: |
    log.level=info
    max.connections=100
    timeout.seconds=30
EOF

kubectl apply -f app-settings.yaml

# Step 2: Create Secret
cat << EOF > app-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  credentials.properties: |
    api.key=abcd1234
    api.secret=efgh5678
EOF

kubectl apply -f app-secrets.yaml

# Step 3: Create Pod with projected volume
cat << EOF > projected-volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: projected-volume-demo
  labels:
    app: demo
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "while true; do ls -la /etc/projected-config; sleep 30; done"]
    volumeMounts:
    - name: projected-config
      mountPath: /etc/projected-config
  volumes:
  - name: projected-config
    projected:
      sources:
      - configMap:
          name: app-settings
      - secret:
          name: app-secrets
          items:
          - key: credentials.properties
            path: credentials.properties
            mode: 0400
      - downwardAPI:
          items:
          - path: "pod-name"
            fieldRef:
              fieldPath: metadata.name
          - path: "pod-namespace"
            fieldRef:
              fieldPath: metadata.namespace
          - path: "pod-labels"
            fieldRef:
              fieldPath: metadata.labels
EOF

kubectl apply -f projected-volume-pod.yaml
```

**Verification**:

```bash
# Verify the Pod is running
kubectl get pod projected-volume-demo

# Check the contents of the projected volume
kubectl exec projected-volume-demo -- ls -la /etc/projected-config

# Check the content of each file
kubectl exec projected-volume-demo -- cat /etc/projected-config/settings.conf
kubectl exec projected-volume-demo -- cat /etc/projected-config/credentials.properties
kubectl exec projected-volume-demo -- cat /etc/projected-config/pod-name
kubectl exec projected-volume-demo -- cat /etc/projected-config/pod-namespace
kubectl exec projected-volume-demo -- cat /etc/projected-config/pod-labels
```

## Exercise 5: CKAD-Style Challenge

**Scenario**: You are deploying a web application that needs both configuration and sensitive data.

**Tasks**:

1. Create a namespace named `web-app`.
2. Create a ConfigMap named `nginx-config` in the `web-app` namespace with a file `nginx.conf`.
3. Create a Secret named `web-creds` in the `web-app` namespace with the following data:
   - `api-key`: `Ax67Btr9Kl`
   - `api-token`: `ZQbn7Xop1T`
4. Create a Pod named `web-server` in the `web-app` namespace with the following specifications:
   - Use the `nginx:1.19` image
   - Mount the `nginx-config` ConfigMap at `/etc/nginx/conf.d/default.conf` using `subPath`
   - Expose the `api-key` and `api-token` as environment variables named `API_KEY` and `API_TOKEN`
   - Add an annotation `deployment=test` to the Pod

You have 10 minutes to complete this challenge.

**Solution**:

```bash
# Step 1: Create namespace
kubectl create namespace web-app

# Step 2: Create nginx.conf
cat << EOF > nginx.conf
server {
    listen 80;
    server_name example.com;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /api {
        proxy_pass http://backend-service;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Create ConfigMap
kubectl create configmap nginx-config --from-file=nginx.conf -n web-app

# Step 3: Create Secret
kubectl create secret generic web-creds \
  --from-literal=api-key=Ax67Btr9Kl \
  --from-literal=api-token=ZQbn7Xop1T \
  -n web-app

# Step 4: Create Pod
cat << EOF > web-server-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  namespace: web-app
  annotations:
    deployment: test
spec:
  containers:
  - name: nginx
    image: nginx:1.19
    env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: web-creds
          key: api-key
    - name: API_TOKEN
      valueFrom:
        secretKeyRef:
          name: web-creds
          key: api-token
    volumeMounts:
    - name: nginx-config-volume
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: nginx.conf
  volumes:
  - name: nginx-config-volume
    configMap:
      name: nginx-config
EOF

kubectl apply -f web-server-pod.yaml
```

**Verification**:

```bash
# Verify the Pod is running
kubectl get pod web-server -n web-app

# Check environment variables
kubectl exec web-server -n web-app -- env | grep -E 'API_KEY|API_TOKEN'

# Check mounted configuration
kubectl exec web-server -n web-app -- cat /etc/nginx/conf.d/default.conf

# Check annotations
kubectl get pod web-server -n web-app -o jsonpath='{.metadata.annotations}'
```

## Exercise 6: Troubleshooting ConfigMaps and Secrets

**Scenario**: You've been given a Pod definition that is supposed to use a ConfigMap and a Secret, but it's not working correctly. Identify and fix the issues.

**Tasks**:

1. Apply the given Pod definition and identify why it's not starting.
2. Fix the issues and ensure the Pod runs correctly.

**Problem Pod Definition**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: problematic-pod
spec:
  containers:
  - name: app
    image: nginx:1.19
    env:
    - name: APP_CONFIG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: config.json
    - name: APP_SECRET
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: api-key
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

**Solution**:

```bash
# First, apply the problematic Pod definition
cat << EOF > problematic-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: problematic-pod
spec:
  containers:
  - name: app
    image: nginx:1.19
    env:
    - name: APP_CONFIG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: config.json
    - name: APP_SECRET
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: api-key
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
EOF

kubectl apply -f problematic-pod.yaml

# Check the Pod status
kubectl get pod problematic-pod
kubectl describe pod problematic-pod

# The issues are:
# 1. The ConfigMap "app-config" doesn't exist
# 2. The Secret "app-secret" doesn't exist

# Create the missing ConfigMap
cat << EOF > config.json
{
  "appName": "FixedApp",
  "version": "1.0.0"
}
EOF

kubectl create configmap app-config --from-file=config.json

# Create the missing Secret
kubectl create secret generic app-secret --from-literal=api-key=fixed-key-123

# Delete and recreate the Pod
kubectl delete pod problematic-pod
kubectl apply -f problematic-pod.yaml

# Verify the Pod is now running
kubectl get pod problematic-pod
```

## Exercise 7: Immutable Secrets with Volume Mounts

**Scenario**: You are working on a critical application where configuration must not change unexpectedly during runtime.

**Tasks**:

1. Create an immutable Secret containing TLS credentials.
2. Deploy a Pod that mounts this Secret as a volume.
3. Attempt to update the Secret and observe the behavior.
4. Create a new version of the Secret and update the Pod to use it.

**Solution**:

```bash
# Step 1: Create a self-signed certificate
mkdir -p tls-certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls-certs/tls.key -out tls-certs/tls.crt \
  -subj "/CN=immutable-example.com"

# Create an immutable Secret
cat << EOF > immutable-tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-tls
type: kubernetes.io/tls
data:
  tls.crt: $(cat tls-certs/tls.crt | base64 -w 0)
  tls.key: $(cat tls-certs/tls.key | base64 -w 0)
immutable: true
EOF

kubectl apply -f immutable-tls-secret.yaml

# Step 2: Deploy a Pod using this Secret
cat << EOF > immutable-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-tls-pod
spec:
  containers:
  - name: app
    image: nginx:1.19
    volumeMounts:
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls-certs
    secret:
      secretName: immutable-tls
EOF

kubectl apply -f immutable-pod.yaml

# Step 3: Try to update the immutable Secret (this should fail)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls-certs/new-tls.key -out tls-certs/new-tls.crt \
  -subj "/CN=updated-example.com"

cat << EOF > update-tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-tls
type: kubernetes.io/tls
data:
  tls.crt: $(cat tls-certs/new-tls.crt | base64 -w 0)
  tls.key: $(cat tls-certs/new-tls.key | base64 -w 0)
immutable: true
EOF

kubectl apply -f update-tls-secret.yaml  # This should fail

# Step 4: Create a new version of the Secret with a different name
cat << EOF > immutable-tls-v2-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-tls-v2
type: kubernetes.io/tls
data:
  tls.crt: $(cat tls-certs/new-tls.crt | base64 -w 0)
  tls.key: $(cat tls-certs/new-tls.key | base64 -w 0)
immutable: true
EOF

kubectl apply -f immutable-tls-v2-secret.yaml

# Update the Pod to use the new Secret
cat << EOF > immutable-pod-v2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-tls-pod-v2
spec:
  containers:
  - name: app
    image: nginx:1.19
    volumeMounts:
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls-certs
    secret:
      secretName: immutable-tls-v2
EOF

kubectl apply -f immutable-pod-v2.yaml
```

## Exercise 8: Using Environment Variables from Multiple Sources

**Scenario**: You're configuring a microservice that needs environment variables from multiple ConfigMaps and Secrets.

**Tasks**:

1. Create two ConfigMaps:
   - `app-env`: with `APP_ENV=production` and `LOG_LEVEL=info`
   - `db-env`: with `DB_HOST=db.example.com` and `DB_PORT=5432`
2. Create one Secret:
   - `db-creds`: with `DB_USER=admin` and `DB_PASS=secure123`
3. Create a Pod that uses all these variables with appropriate prefixes:
   - Variables from `app-env` should have the prefix `APP_`
   - Variables from `db-env` should have the prefix `DB_`
   - Variables from `db-creds` should have no prefix

**Solution**:

```bash
# Step 1: Create the ConfigMaps
kubectl create configmap app-env \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

kubectl create configmap db-env \
  --from-literal=DB_HOST=db.example.com \
  --from-literal=DB_PORT=5432

# Step 2: Create the Secret
kubectl create secret generic db-creds \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=secure123

# Step 3: Create the Pod
cat << EOF > multi-env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-env-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env | sort && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-env
        prefix: APP_
    - configMapRef:
        name: db-env
    - secretRef:
        name: db-creds
EOF

kubectl apply -f multi-env-pod.yaml
```

**Verification**:

```bash
# Verify the Pod is running
kubectl get pod multi-env-app

# Check the environment variables
kubectl logs multi-env-app
```

Expected output should include:
- `APP_APP_ENV=production`
- `APP_LOG_LEVEL=info`
- `DB_HOST=db.example.com`
- `DB_PORT=5432`
- `DB_USER=admin`
- `DB_PASS=secure123`

## Summary

These exercises cover the key concepts of ConfigMaps and Secrets that you need to know for the CKAD exam:

1. Creating ConfigMaps and Secrets using both imperative and declarative approaches
2. Using ConfigMaps and Secrets as environment variables and volumes
3. Understanding immutable configuration objects
4. Working with projected volumes
5. Troubleshooting common issues
6. Using advanced features like `subPath` and environment variable prefixes

Remember these key points:

- ConfigMaps are for non-sensitive configuration data
- Secrets are for sensitive information
- Both can be used as environment variables or mounted as volumes
- Use `optional: true` if your application can function without the configuration
- Set appropriate file permissions (especially for Secrets)
- Understand the update behavior of ConfigMaps and Secrets
- Be aware of the immutability feature and its implications

With these skills, you'll be well-prepared for the configuration-related tasks in the CKAD exam.
