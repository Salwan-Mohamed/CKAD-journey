# 📄 Production-Ready Kubernetes Canary Deployment Manifests

> **Complete YAML configurations** for enterprise-grade canary deployments with advanced features

## 📋 Table of Contents

1. [Basic Canary Setup](#basic-canary-setup)
2. [Production Web Application](#production-web-application)
3. [Microservices Architecture](#microservices-architecture)
4. [Database-Backed Application](#database-backed-application)
5. [Service Mesh Integration](#service-mesh-integration)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [CI/CD Integration](#cicd-integration)
8. [Advanced Configurations](#advanced-configurations)

## 🟦 Basic Canary Setup

### Namespace and RBAC

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: canary-production
  labels:
    environment: production
    deployment-strategy: canary
    monitoring: enabled
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: canary-production
  name: canary-deployer
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: canary-deployer-binding
  namespace: canary-production
subjects:
- kind: ServiceAccount
  name: canary-deployer
  namespace: canary-production
roleRef:
  kind: Role
  name: canary-deployer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: canary-deployer
  namespace: canary-production
  labels:
    app.kubernetes.io/name: canary-deployer
```

### ConfigMap for Application Configuration

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
data:
  app.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      host: postgres-service.database.svc.cluster.local
      port: 5432
      name: webapp_db
      ssl_mode: require
    redis:
      host: redis-service.cache.svc.cluster.local
      port: 6379
    logging:
      level: INFO
      format: json
    features:
      analytics: true
      new_ui: false
      enhanced_auth: false
  prometheus.yaml: |
    metrics:
      enabled: true
      path: /metrics
      port: 9090
    alerts:
      error_rate_threshold: 0.05
      latency_threshold_ms: 1000
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-v2
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/version: v2.0
data:
  app.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      host: postgres-service.database.svc.cluster.local
      port: 5432
      name: webapp_db
      ssl_mode: require
      pool_size: 20  # Increased pool size in v2
    redis:
      host: redis-service.cache.svc.cluster.local
      port: 6379
      cluster_mode: true  # New feature in v2
    logging:
      level: INFO
      format: json
      structured: true  # Enhanced logging in v2
    features:
      analytics: true
      new_ui: true      # New UI enabled in v2
      enhanced_auth: true  # Enhanced auth in v2
      api_v2: true      # New API version
  prometheus.yaml: |
    metrics:
      enabled: true
      path: /metrics
      port: 9090
      custom_metrics: true  # Enhanced metrics in v2
    alerts:
      error_rate_threshold: 0.03  # Stricter threshold
      latency_threshold_ms: 800   # Better performance target
```

## 🌐 Production Web Application

### Stable Version (v1) Deployment

```yaml
# webapp-v1-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/version: v1.0
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ecommerce-platform
    deployment-type: stable
  annotations:
    deployment.kubernetes.io/revision: "1"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
      app.kubernetes.io/version: v1.0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: webapp
        app.kubernetes.io/version: v1.0
        app.kubernetes.io/component: backend
        deployment-type: stable
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
        co.elastic.logs/enabled: "true"
        co.elastic.logs/module: "webapp"
    spec:
      serviceAccountName: canary-deployer
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
      initContainers:
      - name: wait-for-db
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          until pg_isready -h postgres-service.database.svc.cluster.local -p 5432 -U webapp; do
            echo "Waiting for database..."
            sleep 5
          done
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-password
      containers:
      - name: webapp
        image: your-registry.com/webapp:v1.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: VERSION
          value: "1.0"
        - name: ENVIRONMENT
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: redis-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: jwt-secret
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
        - name: tmp
          mountPath: /tmp
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "512Mi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
            httpHeaders:
            - name: Host
              value: localhost
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 20
          timeoutSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health/startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 30
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: config
        configMap:
          name: webapp-config
      - name: tmp
        emptyDir: {}
      nodeSelector:
        kubernetes.io/arch: amd64
        node-type: application
      tolerations:
      - key: application
        operator: Equal
        value: webapp
        effect: NoSchedule
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - webapp
              topologyKey: kubernetes.io/hostname
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

### Canary Version (v2) Deployment

```yaml
# webapp-v2-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/version: v2.0
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: ecommerce-platform
    deployment-type: canary
  annotations:
    deployment.kubernetes.io/revision: "1"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
spec:
  replicas: 1  # Start with 1 replica for canary
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
      app.kubernetes.io/version: v2.0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: webapp
        app.kubernetes.io/version: v2.0
        app.kubernetes.io/component: backend
        deployment-type: canary
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
        co.elastic.logs/enabled: "true"
        co.elastic.logs/module: "webapp"
        fluentd.io/include: "true"  # Enhanced logging in v2
    spec:
      serviceAccountName: canary-deployer
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
      initContainers:
      - name: wait-for-db
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          until pg_isready -h postgres-service.database.svc.cluster.local -p 5432 -U webapp; do
            echo "Waiting for database..."
            sleep 5
          done
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-password
      - name: migration-check
        image: your-registry.com/webapp:v2.0
        command:
        - sh
        - -c
        - |
          echo "Checking database migrations for v2.0..."
          /app/bin/migrate status
          echo "Migration check completed"
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-url
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
      containers:
      - name: webapp
        image: your-registry.com/webapp:v2.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: VERSION
          value: "2.0"
        - name: ENVIRONMENT
          value: "production"
        - name: FEATURE_FLAGS
          value: "new_ui,enhanced_auth,api_v2,analytics_v2"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: redis-url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: jwt-secret
        - name: NEW_FEATURE_API_KEY
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-v2
              key: api-key
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "512Mi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
            httpHeaders:
            - name: Host
              value: localhost
            - name: X-Health-Check
              value: "v2"
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 20
          timeoutSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health/startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 30
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: config
        configMap:
          name: webapp-config-v2
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir:
          sizeLimit: 1Gi
      nodeSelector:
        kubernetes.io/arch: amd64
        node-type: application
      tolerations:
      - key: application
        operator: Equal
        value: webapp
        effect: NoSchedule
      - key: canary
        operator: Equal
        value: true
        effect: NoSchedule
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - webapp
              topologyKey: kubernetes.io/hostname
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

### Service Configuration

```yaml
# webapp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/component: backend
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:region:account:certificate/cert-id
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: webapp
    # Initially only route to stable version
    app.kubernetes.io/version: v1.0
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8080
    protocol: TCP
  sessionAffinity: None
  loadBalancerSourceRanges:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
---
# Service for canary testing (internal)
apiVersion: v1
kind: Service
metadata:
  name: webapp-canary-service
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/component: backend
    service-type: canary
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/version: v2.0
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  sessionAffinity: None
---
# Headless service for service discovery
apiVersion: v1
kind: Service
metadata:
  name: webapp-headless
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: webapp
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
```

## 🛠 Microservices Architecture

### API Gateway with Canary

```yaml
# api-gateway-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: canary-production
  labels:
    app.kubernetes.io/name: api-gateway
    app.kubernetes.io/version: v1.0
    app.kubernetes.io/component: gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: api-gateway
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api-gateway
        app.kubernetes.io/version: v1.0
    spec:
      containers:
      - name: gateway
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: nginx-config
        configMap:
          name: api-gateway-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-gateway-config
  namespace: canary-production
data:
  default.conf: |
    upstream webapp_stable {
        server webapp-service.canary-production.svc.cluster.local:80;
    }
    
    upstream webapp_canary {
        server webapp-canary-service.canary-production.svc.cluster.local:80;
    }
    
    map $request_uri $backend_pool {
        default webapp_stable;
    }
    
    map $http_x_canary_user $backend_pool {
        "true" webapp_canary;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Route 5% of traffic to canary
        location / {
            set $backend webapp_stable;
            
            # Canary routing based on header
            if ($http_x_canary_user = "true") {
                set $backend webapp_canary;
            }
            
            # Random canary routing (5%)
            if ($request_id ~ "[0-4]$") {
                set $backend webapp_canary;
            }
            
            proxy_pass http://$backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

### Microservice Canary with Istio

```yaml
# user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-v1
  namespace: canary-production
  labels:
    app: user-service
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
      version: v1
  template:
    metadata:
      labels:
        app: user-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: user-service
        image: your-registry.com/user-service:v1.0
        ports:
        - containerPort: 8080
        env:
        - name: SERVICE_VERSION
          value: "v1"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-v2
  namespace: canary-production
  labels:
    app: user-service
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
      version: v2
  template:
    metadata:
      labels:
        app: user-service
        version: v2
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: user-service
        image: your-registry.com/user-service:v2.0
        ports:
        - containerPort: 8080
        env:
        - name: SERVICE_VERSION
          value: "v2"
        - name: NEW_FEATURE_ENABLED
          value: "true"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: canary-production
  labels:
    app: user-service
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: user-service
---
# Istio VirtualService for traffic splitting
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: user-service-vs
  namespace: canary-production
spec:
  hosts:
  - user-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: user-service
        subset: v2
  - route:
    - destination:
        host: user-service
        subset: v1
      weight: 90
    - destination:
        host: user-service
        subset: v2
      weight: 10
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: user-service-dr
  namespace: canary-production
spec:
  host: user-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

## 📊 Monitoring and Observability

### ServiceMonitor for Prometheus

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: webapp-monitoring
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    monitoring: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
    honorLabels: true
  namespaceSelector:
    matchNames:
    - canary-production
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webapp-canary-alerts
  namespace: canary-production
  labels:
    app.kubernetes.io/name: webapp
    monitoring: prometheus
spec:
  groups:
  - name: webapp.canary.rules
    rules:
    - alert: CanaryHighErrorRate
      expr: |
        (
          rate(http_requests_total{job="webapp",status=~"5..",version="v2"}[5m]) /
          rate(http_requests_total{job="webapp",version="v2"}[5m])
        ) > 0.05
      for: 2m
      labels:
        severity: critical
        deployment_type: canary
      annotations:
        summary: "High error rate detected in canary deployment"
        description: "Canary version v2 has error rate {{ $value | humanizePercentage }} over the last 5 minutes"
    
    - alert: CanaryHighLatency
      expr: |
        histogram_quantile(0.95,
          rate(http_request_duration_seconds_bucket{job="webapp",version="v2"}[5m])
        ) > 1.0
      for: 2m
      labels:
        severity: warning
        deployment_type: canary
      annotations:
        summary: "High latency detected in canary deployment"
        description: "Canary version v2 has 95th percentile latency of {{ $value }}s"
    
    - alert: CanaryLowTraffic
      expr: |
        rate(http_requests_total{job="webapp",version="v2"}[5m]) == 0
      for: 5m
      labels:
        severity: warning
        deployment_type: canary
      annotations:
        summary: "No traffic reaching canary deployment"
        description: "Canary version v2 is not receiving any traffic for 5 minutes"
```

### Grafana Dashboard ConfigMap

```yaml
# grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: canary-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  canary-deployment.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Canary Deployment Monitoring",
        "tags": ["kubernetes", "canary", "deployment"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate by Version",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{job=\"webapp\"}[5m])",
                "legendFormat": "{{version}} - {{method}} {{status}}"
              }
            ],
            "yAxes": [
              {
                "label": "Requests/sec"
              }
            ],
            "xAxes": [
              {
                "type": "time"
              }
            ]
          },
          {
            "id": 2,
            "title": "Error Rate by Version",
            "type": "singlestat",
            "targets": [
              {
                "expr": "rate(http_requests_total{job=\"webapp\",status=~\"5..\"}[5m]) / rate(http_requests_total{job=\"webapp\"}[5m])",
                "legendFormat": "{{version}}"
              }
            ],
            "valueName": "current",
            "format": "percentunit",
            "thresholds": "0.01,0.05",
            "colorBackground": true
          },
          {
            "id": 3,
            "title": "Response Time (95th percentile)",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"webapp\"}[5m]))",
                "legendFormat": "{{version}} - 95th percentile"
              }
            ],
            "yAxes": [
              {
                "label": "Seconds",
                "min": 0
              }
            ]
          },
          {
            "id": 4,
            "title": "Pod Status",
            "type": "table",
            "targets": [
              {
                "expr": "kube_pod_status_phase{namespace=\"canary-production\",pod=~\"webapp.*\"}",
                "format": "table",
                "instant": true
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

## 🚀 CI/CD Integration

### GitLab CI Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy-canary
  - validate-canary
  - promote
  - cleanup

variables:
  DOCKER_DRIVER: overlay2
  KUBERNETES_NAMESPACE: canary-production
  CANARY_REPLICAS: "1"
  STABLE_REPLICAS: "5"

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
    - develop

unit-tests:
  stage: test
  image: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  script:
    - npm test
    - npm run test:coverage
  coverage: '/Statements.*?(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

deploy-canary:
  stage: deploy-canary
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    # Update canary deployment image
    - |
      kubectl patch deployment webapp-canary -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "template": {
            "spec": {
              "containers": [
                {
                  "name": "webapp",
                  "image": "'$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA'"
                }
              ]
            }
          }
        }
      }'
    
    # Wait for rollout
    - kubectl rollout status deployment/webapp-canary -n $KUBERNETES_NAMESPACE --timeout=300s
    
    # Scale canary to desired replicas
    - kubectl scale deployment webapp-canary --replicas=$CANARY_REPLICAS -n $KUBERNETES_NAMESPACE
    
    # Update service to include canary traffic
    - |
      kubectl patch service webapp-service -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "selector": {
            "app.kubernetes.io/name": "webapp"
          }
        }
      }'
  only:
    - main
  when: manual

validate-canary:
  stage: validate-canary
  image: curlimages/curl:latest
  variables:
    SERVICE_URL: "http://webapp-service.canary-production.svc.cluster.local"
  script:
    # Wait for service to be ready
    - sleep 30
    
    # Run basic health checks
    - |
      for i in $(seq 1 10); do
        response=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL/health)
        if [ "$response" != "200" ]; then
          echo "Health check failed with status $response"
          exit 1
        fi
        echo "Health check $i passed"
        sleep 5
      done
    
    # Test canary responses
    - |
      canary_count=0
      total_requests=20
      
      for i in $(seq 1 $total_requests); do
        response=$(curl -s $SERVICE_URL | grep -o "Version [0-9.]*")
        echo "Request $i: $response"
        
        if echo "$response" | grep -q "Version 2"; then
          canary_count=$((canary_count + 1))
        fi
        
        sleep 1
      done
      
      canary_percentage=$((canary_count * 100 / total_requests))
      echo "Canary traffic percentage: $canary_percentage%"
      
      # Expect at least 10% canary traffic
      if [ $canary_percentage -lt 10 ]; then
        echo "Insufficient canary traffic detected"
        exit 1
      fi
  only:
    - main
  dependencies:
    - deploy-canary

promote-canary:
  stage: promote
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    # Scale up canary
    - kubectl scale deployment webapp-canary --replicas=$STABLE_REPLICAS -n $KUBERNETES_NAMESPACE
    - kubectl rollout status deployment/webapp-canary -n $KUBERNETES_NAMESPACE --timeout=300s
    
    # Scale down stable
    - kubectl scale deployment webapp-stable --replicas=1 -n $KUBERNETES_NAMESPACE
    
    # Wait and monitor
    - sleep 60
    
    # Full cutover to canary
    - |
      kubectl patch service webapp-service -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "selector": {
            "app.kubernetes.io/name": "webapp",
            "app.kubernetes.io/version": "v2.0"
          }
        }
      }'
    
    # Update stable deployment to new version
    - |
      kubectl patch deployment webapp-stable -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "template": {
            "spec": {
              "containers": [
                {
                  "name": "webapp",
                  "image": "'$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA'"
                }
              ]
            }
          }
        }
      }'
    
    # Scale stable back up and canary down
    - kubectl scale deployment webapp-stable --replicas=$STABLE_REPLICAS -n $KUBERNETES_NAMESPACE
    - kubectl scale deployment webapp-canary --replicas=0 -n $KUBERNETES_NAMESPACE
    
    # Switch service back to stable (now v2)
    - |
      kubectl patch service webapp-service -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "selector": {
            "app.kubernetes.io/name": "webapp",
            "app.kubernetes.io/version": "v2.0"
          }
        }
      }'
  only:
    - main
  when: manual
  dependencies:
    - validate-canary

rollback:
  stage: cleanup
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    # Emergency rollback to stable v1
    - |
      kubectl patch service webapp-service -n $KUBERNETES_NAMESPACE -p '{
        "spec": {
          "selector": {
            "app.kubernetes.io/name": "webapp",
            "app.kubernetes.io/version": "v1.0"
          }
        }
      }'
    
    # Scale up stable v1
    - kubectl scale deployment webapp-stable --replicas=$STABLE_REPLICAS -n $KUBERNETES_NAMESPACE
    
    # Scale down canary
    - kubectl scale deployment webapp-canary --replicas=0 -n $KUBERNETES_NAMESPACE
    
    echo "Rollback completed - all traffic routed to stable v1"
  only:
    - main
  when: manual
```

## 🎓 Next Steps

These production-ready YAML examples provide:

✅ **Complete deployment pipeline** with proper resource management  
✅ **Security best practices** with RBAC and security contexts  
✅ **Monitoring integration** with Prometheus and Grafana  
✅ **Service mesh support** with Istio traffic splitting  
✅ **CI/CD automation** with GitLab pipelines  
✅ **Emergency procedures** with rollback capabilities  

Continue learning with:
- **[Advanced Strategies](canary-advanced-strategies.md)** - Service mesh and automation
- **[Troubleshooting Guide](canary-troubleshooting.md)** - Debug common issues

---

**🎨 Ready to customize these manifests for your environment!**