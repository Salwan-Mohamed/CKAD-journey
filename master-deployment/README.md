# Master Deployment Guide for CKAD

This folder contains comprehensive guides and examples for understanding Kubernetes Deployments, a critical topic for the Certified Kubernetes Application Developer (CKAD) exam.

## Contents

1. **[Master Deployment Guide](./master-deployment-guide.md)** - A comprehensive overview of Kubernetes Deployments covering all the essential concepts
2. **[Deployment Examples and Hands-on Practice](./deployment-examples.md)** - Practical examples and exercises to help you gain hands-on experience
3. **[Mastering Deployment Rolling Updates](./deployment-rolling-updates.md)** - Detailed guide to rolling updates, a key feature of Deployments
4. **[Deployment Strategies and Troubleshooting](./deployment-strategies-troubleshooting.md)** - Advanced deployment strategies and troubleshooting techniques
5. **[Deployment YAML Examples](./deployment-yaml-examples.md)** - Ready-to-use YAML templates for various deployment configurations

## Key Deployment Concepts for CKAD

The CKAD exam places significant importance on understanding Deployments. Make sure you understand:

- Creating and managing Deployments
- Scaling Deployments
- Updating Deployments with different strategies
- Rolling back Deployments
- Debugging common Deployment issues

## Quick Reference

### Create a Deployment

```bash
# Imperative
kubectl create deployment my-app --image=nginx --replicas=3

# Declarative
kubectl apply -f deployment.yaml
```

### Scale a Deployment

```bash
kubectl scale deployment my-app --replicas=5
```

### Update a Deployment Image

```bash
kubectl set image deployment/my-app my-app=nginx:1.19.0
```

### Check Deployment Status

```bash
kubectl rollout status deployment/my-app
```

### Rollback a Deployment

```bash
kubectl rollout undo deployment/my-app
```

### Generate a Deployment YAML Template

```bash
kubectl create deployment my-app --image=nginx --dry-run=client -o yaml > deployment.yaml
```

## Deployment YAML Structure

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:1.0.0
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
```

## Study Tips

1. Practice creating Deployments both imperatively and declaratively
2. Understand the relationship between Deployments, ReplicaSets, and Pods
3. Master the various deployment strategies and know when to use each
4. Practice troubleshooting common Deployment issues
5. Get comfortable with updating Deployments and rolling back changes
6. Understand how resources, probes, and environment variables work with Deployments

Good luck with your CKAD exam preparation!