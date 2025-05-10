# Kubernetes Container Health Checks - Index

This directory contains comprehensive resources on Kubernetes container health probes for CKAD exam preparation.

## Main Documentation

- [README.md](./README.md) - Complete guide to Kubernetes container health probes

## Quick Resources

- [Quick Reference](./quick-reference.md) - Essential reference card for the CKAD exam
- [Commands Cheatsheet](./commands-cheatsheet.md) - Useful commands for working with container health probes

## Practical Materials

- [Practical Exercises](./practical-exercises.md) - Hands-on exercises to practice implementing probes
- [Troubleshooting Guide](./troubleshooting-guide.md) - Solutions for common health probe issues

## Example YAML Files

- [Web Application Example](./web-app-example.yaml) - Example of a web application with all three probe types
- [Database Example](./database-example.yaml) - Example of a database with appropriate health checks
- [Worker Example](./worker-example.yaml) - Example of a background worker with exec probes
- [Readiness Gate Example](./readiness-gate-example.yaml) - Example of using readiness gates

## Visual Resources

The `./images/` directory contains diagrams to help visualize health probe concepts:

- [Container Health Probe Types](./images/probe-types.svg) - Overview of the three probe types
- [Probe Mechanisms](./images/probe-mechanisms.svg) - Illustration of HTTP, TCP, and Exec probe mechanisms
- [Container Lifecycle](./images/container-lifecycle.svg) - Timeline showing how probes relate to container lifecycle
- [Pod Configuration Example](./images/pod-config.svg) - Annotated YAML example

## Study Tips

1. Understand the **purpose** of each probe type:
   - Startup probes for initialization
   - Liveness probes for runtime health
   - Readiness probes for traffic management

2. Know when to use each **probe mechanism**:
   - HTTP GET for web applications
   - TCP Socket for network services
   - Exec for custom scripts and checks

3. Practice setting appropriate **configuration parameters**:
   - initialDelaySeconds
   - periodSeconds
   - timeoutSeconds
   - failureThreshold
   - successThreshold

4. Learn to **troubleshoot** common health probe issues.

5. Understand how probes affect **pod conditions** and service availability.

## CKAD Exam Relevance

Container health probes are an important topic for the CKAD exam because they:

- Demonstrate understanding of application lifecycle management
- Show knowledge of self-healing mechanisms in Kubernetes
- Require practical application of pod and container configuration
- Involve multiple Kubernetes concepts working together
- Are essential for production-ready applications

When studying for the CKAD exam, focus on being able to quickly implement appropriate probes for different application types, as well as understanding how to troubleshoot issues with probes.
