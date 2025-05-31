# 📊 Canary Deployment Monitoring and Observability

> **Complete monitoring setup** for production-grade canary deployments with Prometheus, Grafana, and alerting

## 📋 Table of Contents

1. [Monitoring Stack Overview](#monitoring-stack-overview)
2. [Prometheus Configuration](#prometheus-configuration)
3. [Grafana Dashboards](#grafana-dashboards)
4. [Alerting Rules](#alerting-rules)
5. [Custom Metrics](#custom-metrics)
6. [Log Aggregation](#log-aggregation)
7. [SLI/SLO Definitions](#slislo-definitions)
8. [Runbooks](#runbooks)

## 🏗 Monitoring Stack Overview

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │───▶│   Prometheus    │───▶│     Grafana     │
│                 │    │                 │    │                 │
│ - webapp-v1     │    │ - Metrics       │    │ - Dashboards    │
│ - webapp-v2     │    │ - Alerts        │    │ - Visualization │
│ - Canary Pods   │    │ - Recording     │    │ - Analysis      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                        │                        │
          │                        ▼                        │
          │            ┌─────────────────┐                 │
          │            │  AlertManager   │                 │
          │            │                 │                 │
          │            │ - Notifications │                 │
          │            │ - Routing       │                 │
          │            │ - Inhibition    │                 │
          │            └─────────────────┘                 │
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Jaeger       │    │     Slack       │    │   PagerDuty     │
│                 │    │                 │    │                 │
│ - Distributed   │    │ - Team Alerts   │    │ - Incident      │
│   Tracing       │    │ - Notifications │    │   Management    │
│ - Performance   │    │ - Channels      │    │ - Escalation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Core Components

```yaml
# monitoring-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    monitoring: enabled
---
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging
    logging: enabled
```

## 🎯 Prometheus Configuration

### ServiceMonitor for Canary Deployments

```yaml
# prometheus-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: webapp-canary-monitor
  namespace: monitoring
  labels:
    app: webapp
    monitoring: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
  namespaceSelector:
    matchNames:
    - production
    - staging
  endpoints:
  - port: metrics
    path: /metrics
    interval: 15s
    scrapeTimeout: 10s
    honorLabels: true
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_label_version]
      targetLabel: version
    - sourceLabels: [__meta_kubernetes_pod_label_deployment_type]
      targetLabel: deployment_type
    - sourceLabels: [__meta_kubernetes_namespace]
      targetLabel: namespace
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: 'go_.*'
      action: drop  # Drop Go runtime metrics to reduce cardinality
---
# Additional ServiceMonitor for Istio metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: webapp-istio-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: istiod
  endpoints:
  - port: http-monitoring
    interval: 15s
    path: /stats/prometheus
---
# ServiceMonitor for Envoy sidecars
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: webapp-envoy-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: webapp
  podMetricsEndpoints:
  - port: http-envoy-prom
    path: /stats/prometheus
    interval: 15s
```

### Prometheus Recording Rules

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webapp-canary-rules
  namespace: monitoring
  labels:
    app: webapp
    monitoring: prometheus
spec:
  groups:
  - name: webapp.canary.recording
    interval: 30s
    rules:
    # Request rate by version
    - record: webapp:http_requests:rate5m
      expr: |
        rate(http_requests_total{job="webapp"}[5m])
    
    # Error rate by version
    - record: webapp:http_errors:rate5m
      expr: |
        rate(http_requests_total{job="webapp",status=~"5.."}[5m])
    
    # Success rate by version
    - record: webapp:http_success_rate:rate5m
      expr: |
        (
          rate(http_requests_total{job="webapp"}[5m]) -
          rate(http_requests_total{job="webapp",status=~"5.."}[5m])
        ) / rate(http_requests_total{job="webapp"}[5m])
    
    # Average response time by version
    - record: webapp:http_duration:avg5m
      expr: |
        rate(http_request_duration_seconds_sum{job="webapp"}[5m]) /
        rate(http_request_duration_seconds_count{job="webapp"}[5m])
    
    # 95th percentile response time
    - record: webapp:http_duration:p95_5m
      expr: |
        histogram_quantile(0.95,
          rate(http_request_duration_seconds_bucket{job="webapp"}[5m])
        )
    
    # 99th percentile response time
    - record: webapp:http_duration:p99_5m
      expr: |
        histogram_quantile(0.99,
          rate(http_request_duration_seconds_bucket{job="webapp"}[5m])
        )
    
    # Traffic distribution percentage
    - record: webapp:traffic_distribution:percentage
      expr: |
        (
          sum(rate(http_requests_total{job="webapp"}[5m])) by (version) /
          sum(rate(http_requests_total{job="webapp"}[5m]))
        ) * 100
    
    # Canary vs Stable comparison
    - record: webapp:canary_vs_stable:error_rate_ratio
      expr: |
        (
          webapp:http_errors:rate5m{version="v2"} /
          webapp:http_requests:rate5m{version="v2"}
        ) / (
          webapp:http_errors:rate5m{version="v1"} /
          webapp:http_requests:rate5m{version="v1"}
        )
```

## 📈 Grafana Dashboards

### Main Canary Dashboard

```json
{
  "dashboard": {
    "id": null,
    "title": "Kubernetes Canary Deployment Monitoring",
    "tags": ["kubernetes", "canary", "deployment"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Traffic Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "webapp:traffic_distribution:percentage",
            "legendFormat": "{{version}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "hideFrom": {
                "tooltip": false,
                "vis": false,
                "legend": false
              }
            },
            "mappings": [],
            "unit": "percent"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Request Rate by Version",
        "type": "timeseries",
        "targets": [
          {
            "expr": "webapp:http_requests:rate5m",
            "legendFormat": "{{version}} - {{method}} {{status}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "barAlignment": 0,
              "lineWidth": 1,
              "fillOpacity": 10,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {
                "mode": "none",
                "group": "A"
              },
              "axisPlacement": "auto",
              "axisLabel": "",
              "scaleDistribution": {
                "type": "linear"
              },
              "hideFrom": {
                "tooltip": false,
                "vis": false,
                "legend": false
              },
              "thresholdsStyle": {
                "mode": "off"
              }
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            },
            "unit": "reqps"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 3,
        "title": "Error Rate Comparison",
        "type": "stat",
        "targets": [
          {
            "expr": "webapp:http_success_rate:rate5m{version=\"v1\"}",
            "legendFormat": "Stable (v1)"
          },
          {
            "expr": "webapp:http_success_rate:rate5m{version=\"v2\"}",
            "legendFormat": "Canary (v2)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "red",
                  "value": null
                },
                {
                  "color": "yellow",
                  "value": 0.95
                },
                {
                  "color": "green",
                  "value": 0.99
                }
              ]
            },
            "unit": "percentunit",
            "min": 0,
            "max": 1
          }
        },
        "gridPos": {
          "h": 8,
          "w": 24,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 4,
        "title": "Response Time (P95)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "webapp:http_duration:p95_5m",
            "legendFormat": "{{version}} - P95"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "linear",
              "barAlignment": 0,
              "lineWidth": 1,
              "fillOpacity": 10,
              "gradientMode": "none",
              "spanNulls": false,
              "insertNulls": false,
              "showPoints": "never",
              "pointSize": 5,
              "stacking": {
                "mode": "none",
                "group": "A"
              },
              "axisPlacement": "auto",
              "axisLabel": "",
              "scaleDistribution": {
                "type": "linear"
              },
              "hideFrom": {
                "tooltip": false,
                "vis": false,
                "legend": false
              },
              "thresholdsStyle": {
                "mode": "off"
              }
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            },
            "unit": "s"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 16
        }
      },
      {
        "id": 5,
        "title": "Pod Status",
        "type": "table",
        "targets": [
          {
            "expr": "kube_pod_info{namespace=\"production\",pod=~\"webapp.*\"}",
            "format": "table",
            "instant": true
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "align": "auto",
              "displayMode": "auto"
            },
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            }
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 16
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {},
    "timezone": "",
    "refresh": "30s",
    "schemaVersion": 27,
    "version": 0,
    "links": []
  }
}
```

### ConfigMap for Dashboard

```yaml
# grafana-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: canary-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  canary-deployment-monitoring.json: |
    # [Include the complete JSON dashboard above]
```

## 🚨 Alerting Rules

### Comprehensive Alert Configuration

```yaml
# canary-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webapp-canary-alerts
  namespace: monitoring
  labels:
    app: webapp
    monitoring: prometheus
spec:
  groups:
  - name: webapp.canary.critical
    rules:
    - alert: CanaryHighErrorRate
      expr: |
        (
          webapp:http_errors:rate5m{version="v2"} /
          webapp:http_requests:rate5m{version="v2"}
        ) > 0.05
      for: 2m
      labels:
        severity: critical
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary deployment has high error rate"
        description: "Canary version v2 has error rate {{ $value | humanizePercentage }} over the last 5 minutes"
        runbook_url: "https://docs.company.com/runbooks/canary-rollback"
        dashboard_url: "https://grafana.company.com/d/canary-dashboard"
    
    - alert: CanaryHighLatency
      expr: |
        webapp:http_duration:p95_5m{version="v2"} > 1.0
      for: 2m
      labels:
        severity: critical
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary deployment has high latency"
        description: "Canary version v2 has 95th percentile latency of {{ $value }}s"
        runbook_url: "https://docs.company.com/runbooks/canary-performance"
    
    - alert: CanaryVsStableErrorRatio
      expr: |
        webapp:canary_vs_stable:error_rate_ratio > 2.0
      for: 3m
      labels:
        severity: critical
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary error rate significantly higher than stable"
        description: "Canary error rate is {{ $value }}x higher than stable version"
        runbook_url: "https://docs.company.com/runbooks/canary-comparison"
  
  - name: webapp.canary.warning
    rules:
    - alert: CanaryLowTraffic
      expr: |
        absent_over_time(webapp:http_requests:rate5m{version="v2"}[10m])
      for: 5m
      labels:
        severity: warning
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary deployment receiving no traffic"
        description: "No requests to canary version in the last 10 minutes"
        runbook_url: "https://docs.company.com/runbooks/canary-traffic"
    
    - alert: CanaryPodDown
      expr: |
        up{job="webapp",version="v2"} == 0
      for: 1m
      labels:
        severity: warning
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary pod is down"
        description: "Canary pod {{ $labels.instance }} has been down for more than 1 minute"
        runbook_url: "https://docs.company.com/runbooks/canary-pod-health"
    
    - alert: CanaryResourceUsage
      expr: |
        (
          rate(container_cpu_usage_seconds_total{pod=~"webapp.*v2.*"}[5m]) * 100
        ) > 80
      for: 5m
      labels:
        severity: warning
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary pod high CPU usage"
        description: "Canary pod {{ $labels.pod }} CPU usage is {{ $value }}%"
    
    - alert: CanaryMemoryUsage
      expr: |
        (
          container_memory_working_set_bytes{pod=~"webapp.*v2.*"} /
          container_spec_memory_limit_bytes{pod=~"webapp.*v2.*"}
        ) * 100 > 85
      for: 5m
      labels:
        severity: warning
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary pod high memory usage"
        description: "Canary pod {{ $labels.pod }} memory usage is {{ $value }}%"
  
  - name: webapp.canary.info
    rules:
    - alert: CanaryDeploymentStarted
      expr: |
        increase(kube_deployment_status_replicas{deployment="webapp-canary"}[5m]) > 0
      for: 0m
      labels:
        severity: info
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary deployment started"
        description: "New canary deployment has been initiated"
    
    - alert: CanaryTrafficIncrease
      expr: |
        increase(webapp:traffic_distribution:percentage{version="v2"}[10m]) > 10
      for: 0m
      labels:
        severity: info
        deployment_type: canary
        service: webapp
      annotations:
        summary: "Canary traffic percentage increased"
        description: "Canary traffic increased by {{ $value }}% in the last 10 minutes"
```

## 📏 Custom Metrics

### Application-Level Metrics

```yaml
# custom-metrics-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-metrics-config
  namespace: production
data:
  metrics.yaml: |
    metrics:
      # Business metrics
      business:
        - name: checkout_conversions_total
          help: "Total number of successful checkouts"
          type: counter
          labels:
            - version
            - payment_method
            - user_segment
        
        - name: user_sessions_duration_seconds
          help: "Duration of user sessions in seconds"
          type: histogram
          buckets: [1, 5, 10, 30, 60, 300, 600, 1800, 3600]
          labels:
            - version
            - user_type
        
        - name: api_calls_by_endpoint_total
          help: "Total API calls by endpoint"
          type: counter
          labels:
            - version
            - endpoint
            - method
            - status_code
      
      # Feature-specific metrics
      features:
        - name: feature_flag_evaluations_total
          help: "Total feature flag evaluations"
          type: counter
          labels:
            - version
            - flag_name
            - variation
            - user_segment
        
        - name: new_feature_usage_total
          help: "Usage of new features in canary"
          type: counter
          labels:
            - version
            - feature_name
            - success
      
      # Performance metrics
      performance:
        - name: database_query_duration_seconds
          help: "Database query execution time"
          type: histogram
          buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
          labels:
            - version
            - query_type
            - table
        
        - name: cache_hit_ratio
          help: "Cache hit ratio"
          type: gauge
          labels:
            - version
            - cache_type
        
        - name: external_api_calls_total
          help: "External API calls"
          type: counter
          labels:
            - version
            - service
            - status
```

### Metrics Collection Script

```python
# metrics_collector.py - Example Python metrics implementation
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from flask import Flask, Response
import time
import os

app = Flask(__name__)

# Define metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status', 'version']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint', 'version']
)

CHECKOUT_CONVERSIONS = Counter(
    'checkout_conversions_total',
    'Total successful checkouts',
    ['version', 'payment_method', 'user_segment']
)

FEATURE_FLAG_EVALUATIONS = Counter(
    'feature_flag_evaluations_total',
    'Feature flag evaluations',
    ['version', 'flag_name', 'variation', 'user_segment']
)

ACTIVE_USERS = Gauge(
    'active_users_current',
    'Current active users',
    ['version']
)

version = os.getenv('APP_VERSION', 'unknown')

def track_request(method, endpoint, status):
    """Track HTTP request metrics"""
    REQUEST_COUNT.labels(
        method=method,
        endpoint=endpoint,
        status=status,
        version=version
    ).inc()

def track_request_duration(method, endpoint, duration):
    """Track request duration"""
    REQUEST_DURATION.labels(
        method=method,
        endpoint=endpoint,
        version=version
    ).observe(duration)

def track_checkout_conversion(payment_method, user_segment):
    """Track successful checkout"""
    CHECKOUT_CONVERSIONS.labels(
        version=version,
        payment_method=payment_method,
        user_segment=user_segment
    ).inc()

def track_feature_flag(flag_name, variation, user_segment):
    """Track feature flag evaluation"""
    FEATURE_FLAG_EVALUATIONS.labels(
        version=version,
        flag_name=flag_name,
        variation=variation,
        user_segment=user_segment
    ).inc()

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), mimetype='text/plain')

@app.route('/health')
def health():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'version': version,
        'timestamp': time.time()
    }

@app.route('/checkout', methods=['POST'])
def checkout():
    """Example checkout endpoint with metrics"""
    start_time = time.time()
    
    try:
        # Simulate checkout logic
        payment_method = request.json.get('payment_method', 'card')
        user_segment = request.json.get('user_segment', 'regular')
        
        # Track successful checkout
        track_checkout_conversion(payment_method, user_segment)
        track_request('POST', '/checkout', '200')
        
        duration = time.time() - start_time
        track_request_duration('POST', '/checkout', duration)
        
        return {'status': 'success', 'version': version}
    
    except Exception as e:
        track_request('POST', '/checkout', '500')
        return {'status': 'error', 'message': str(e)}, 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

## 📜 Log Aggregation

### Fluentd Configuration

```yaml
# fluentd-canary-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-canary-config
  namespace: logging
data:
  fluent.conf: |
    <source>
      @type tail
      @id canary_logs
      path /var/log/containers/webapp-*canary*.log
      pos_file /var/log/fluentd-canary.log.pos
      tag kubernetes.canary.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
        time_key time
        keep_time_key true
      </parse>
    </source>
    
    <filter kubernetes.canary.**>
      @type kubernetes_metadata
      @id filter_canary_metadata
      kubernetes_url "#{ENV['KUBERNETES_SERVICE_HOST']}:#{ENV['KUBERNETES_SERVICE_PORT_HTTPS']}"
      verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL'] || true}"
      ca_file "#{ENV['KUBERNETES_CA_FILE']}"
      skip_labels false
      skip_container_metadata false
      skip_master_url false
      skip_namespace_metadata false
    </filter>
    
    <filter kubernetes.canary.**>
      @type record_transformer
      @id filter_canary_enrichment
      <record>
        deployment_type canary
        environment production
        service_name webapp
        log_type application
        canary_version "#{ENV['CANARY_VERSION'] || 'unknown'}"
      </record>
    </filter>
    
    # Parse application logs
    <filter kubernetes.canary.**>
      @type parser
      @id filter_canary_parser
      key_name log
      reserve_data true
      remove_key_name_field true
      <parse>
        @type multi_format
        <pattern>
          format json
          time_key timestamp
          time_format %Y-%m-%dT%H:%M:%S.%L%z
        </pattern>
        <pattern>
          format regexp
          expression /^(?<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)\s+(?<level>\w+)\s+(?<logger>[\w\.]+)\s+(?<message>.*)/
        </pattern>
      </parse>
    </filter>
    
    # Route to different outputs based on log level
    <match kubernetes.canary.**>
      @type copy
      <store>
        @type elasticsearch
        @id elasticsearch_canary
        host elasticsearch.logging.svc.cluster.local
        port 9200
        logstash_format true
        logstash_prefix canary-logs
        logstash_dateformat %Y.%m.%d
        include_tag_key true
        type_name _doc
        tag_key @log_name
        <buffer>
          @type file
          path /var/log/fluentd-buffers/canary.buffer
          flush_mode interval
          retry_type exponential_backoff
          flush_thread_count 2
          flush_interval 5s
          retry_forever
          retry_max_interval 30
          chunk_limit_size 2M
          queue_limit_length 8
          overflow_action block
        </buffer>
      </store>
      
      # Send ERROR logs to alerting
      <store>
        @type copy
        <store>
          @type slack
          @id slack_canary_errors
          webhook_url "#{ENV['SLACK_WEBHOOK_URL']}"
          title "Canary Error Alert"
          message "Error in canary deployment: %s"
          message_keys message
          <format>
            @type json
          </format>
          <buffer>
            flush_interval 30s
          </buffer>
        </store>
        <store>
          @type stdout
          @id stdout_canary_errors
          <format>
            @type json
          </format>
        </store>
      </store>
    </match>
```

## 🎯 SLI/SLO Definitions

### Service Level Objectives

```yaml
# slo-definitions.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-slo-definitions
  namespace: monitoring
data:
  slo.yaml: |
    service_level_objectives:
      webapp_availability:
        description: "Web application availability"
        sli_specification:
          ratio_metric:
            numerator:
              metric_name: "webapp:http_requests:rate5m"
              filters:
                - "status!~'5..'"
            denominator:
              metric_name: "webapp:http_requests:rate5m"
        objectives:
          - target: 0.999  # 99.9% availability
            period: "30d"
          - target: 0.995  # 99.5% availability  
            period: "7d"
        
      webapp_latency:
        description: "Web application response latency"
        sli_specification:
          threshold_metric:
            metric_name: "webapp:http_duration:p95_5m"
            threshold: 0.5  # 500ms
        objectives:
          - target: 0.95   # 95% of requests under 500ms
            period: "30d"
          - target: 0.99   # 99% of requests under 500ms
            period: "7d"
      
      canary_comparison:
        description: "Canary vs Stable comparison"
        sli_specification:
          ratio_metric:
            numerator:
              metric_name: "webapp:canary_vs_stable:error_rate_ratio"
              filters:
                - "value <= 1.5"  # Canary error rate not more than 1.5x stable
            denominator:
              metric_name: "webapp:canary_vs_stable:error_rate_ratio"
        objectives:
          - target: 0.95   # 95% of time canary performs as well as stable
            period: "1d"
    
    error_budget_policies:
      fast_burn:
        condition: "error_budget_remaining < 0.02"  # Less than 2% remaining
        action: "immediate_rollback"
        notification: "pagerduty_critical"
      
      slow_burn:
        condition: "error_budget_remaining < 0.1"   # Less than 10% remaining
        action: "alert_oncall"
        notification: "slack_warning"
      
      budget_exhausted:
        condition: "error_budget_remaining <= 0"
        action: "freeze_deployments"
        notification: "pagerduty_critical,slack_critical"
```

### SLO Monitoring Queries

```yaml
# slo-monitoring-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: webapp-slo-monitoring
  namespace: monitoring
spec:
  groups:
  - name: webapp.slo.availability
    interval: 60s
    rules:
    - record: webapp:slo:availability:7d
      expr: |
        1 - (
          sum(rate(webapp:http_errors:rate5m[7d])) /
          sum(rate(webapp:http_requests:rate5m[7d]))
        )
    
    - record: webapp:slo:availability:30d
      expr: |
        1 - (
          sum(rate(webapp:http_errors:rate5m[30d])) /
          sum(rate(webapp:http_requests:rate5m[30d]))
        )
    
    - record: webapp:slo:error_budget_remaining:7d
      expr: |
        (webapp:slo:availability:7d - 0.995) / (1 - 0.995)
    
    - record: webapp:slo:error_budget_remaining:30d
      expr: |
        (webapp:slo:availability:30d - 0.999) / (1 - 0.999)
  
  - name: webapp.slo.latency
    interval: 60s
    rules:
    - record: webapp:slo:latency:7d
      expr: |
        (
          sum(rate(http_request_duration_seconds_bucket{job="webapp",le="0.5"}[7d])) /
          sum(rate(http_request_duration_seconds_count{job="webapp"}[7d]))
        )
    
    - record: webapp:slo:latency:30d
      expr: |
        (
          sum(rate(http_request_duration_seconds_bucket{job="webapp",le="0.5"}[30d])) /
          sum(rate(http_request_duration_seconds_count{job="webapp"}[30d]))
        )
```

## 📚 Runbooks

### Canary Deployment Runbook

```markdown
# Canary Deployment Incident Response Runbook

## 🚨 Alert: CanaryHighErrorRate

### Immediate Actions (< 5 minutes)

1. **Verify Alert Accuracy**
   ```bash
   # Check current error rate
   kubectl logs -l app=webapp,version=v2 -n production --tail=100
   
   # Verify metrics in Prometheus
   curl -G 'http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query' \
     --data-urlencode 'query=webapp:http_success_rate:rate5m{version="v2"}'
   ```

2. **Assess Impact**
   - Check traffic percentage to canary
   - Determine number of affected users
   - Review error patterns in logs

3. **Immediate Mitigation**
   ```bash
   # Option 1: Route traffic back to stable
   kubectl patch service webapp-service -n production -p='{
     "spec": {
       "selector": {
         "app": "webapp",
         "version": "v1"
       }
     }
   }'
   
   # Option 2: Scale down canary
   kubectl scale deployment webapp-canary --replicas=0 -n production
   ```

### Investigation (5-15 minutes)

1. **Root Cause Analysis**
   ```bash
   # Check recent deployments
   kubectl rollout history deployment/webapp-canary -n production
   
   # Review application logs
   kubectl logs -l app=webapp,version=v2 -n production --since=30m
   
   # Check resource usage
   kubectl top pods -l app=webapp,version=v2 -n production
   
   # Review recent changes
   git log --oneline --since="2 hours ago"
   ```

2. **Health Check Analysis**
   ```bash
   # Test health endpoints
   kubectl exec -it debug-pod -n production -- \
     curl -v http://webapp-canary-service.production.svc.cluster.local/health
   
   # Check database connectivity
   kubectl exec -it webapp-canary-xxx -n production -- \
     nc -zv postgres-service.database.svc.cluster.local 5432
   ```

### Resolution (15-30 minutes)

1. **If Code Issue**
   - Create hotfix branch
   - Deploy fix to canary
   - Gradually restore traffic

2. **If Configuration Issue**
   - Update ConfigMap/Secret
   - Restart canary deployment
   - Monitor for improvements

3. **If Infrastructure Issue**
   - Check node health
   - Review network policies
   - Verify resource availability

### Post-Incident (30+ minutes)

1. **Documentation**
   - Update incident log
   - Create post-mortem
   - Document lessons learned

2. **Prevention**
   - Update testing procedures
   - Improve monitoring/alerting
   - Review deployment process

## 🚨 Alert: CanaryHighLatency

### Immediate Actions

1. **Performance Investigation**
   ```bash
   # Check current latency
   kubectl exec -it webapp-canary-xxx -n production -- \
     curl -w "%{time_total}" http://localhost:8080/api/endpoint
   
   # Review database performance
   kubectl logs -l app=postgres -n database --tail=50
   
   # Check resource constraints
   kubectl describe pod webapp-canary-xxx -n production
   ```

2. **Traffic Management**
   ```bash
   # Reduce canary traffic
   kubectl scale deployment webapp-canary --replicas=1 -n production
   
   # Or route high-priority traffic to stable
   # Update VirtualService for Istio
   kubectl patch virtualservice webapp-vs -n production --type='merge' -p='{
     "spec": {
       "http": [{
         "match": [{
           "headers": {
             "priority": {
               "exact": "high"
             }
           }
         }],
         "route": [{
           "destination": {
             "host": "webapp-service",
             "subset": "v1"
           }
         }]
       }]
     }
   }'
   ```

### Performance Optimization

1. **Resource Adjustment**
   ```bash
   # Increase resource limits
   kubectl patch deployment webapp-canary -n production -p='{
     "spec": {
       "template": {
         "spec": {
           "containers": [{
             "name": "webapp",
             "resources": {
               "requests": {
                 "memory": "512Mi",
                 "cpu": "500m"
               },
               "limits": {
                 "memory": "1Gi",
                 "cpu": "1000m"
               }
             }
           }]
         }
       }
     }
   }'
   ```

2. **Database Optimization**
   - Check slow query logs
   - Review connection pooling
   - Verify indexes

3. **Caching Review**
   - Check cache hit rates
   - Verify cache configuration
   - Review cache invalidation

## Contact Information

- **On-Call Engineer**: @oncall-platform
- **Platform Team**: @platform-team
- **Database Team**: @database-team
- **Security Team**: @security-team

## Escalation Matrix

1. **Level 1** (0-15 min): On-call engineer
2. **Level 2** (15-30 min): Platform team lead
3. **Level 3** (30+ min): Engineering manager
4. **Level 4** (1+ hour): VP Engineering
```

---

**📊 Complete monitoring setup achieved! Your canary deployments are now fully observable and automated.**