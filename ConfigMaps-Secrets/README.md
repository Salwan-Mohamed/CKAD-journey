# ConfigMaps & Secrets in Kubernetes

![ConfigMaps and Secrets Banner](https://raw.githubusercontent.com/Salwan-Mohamed/CKAD-journey/add-configmaps-secrets/ConfigMaps-Secrets/images/configmaps-secrets-banner.svg)

## Introduction

Configuration management is a critical aspect of deploying applications in Kubernetes. This module focuses on two key Kubernetes objects that help manage configuration data:

- **ConfigMaps**: For storing non-sensitive configuration data
- **Secrets**: For storing sensitive information like credentials and certificates

Both objects help to decouple configuration from your application code and container images, making your applications more portable and easier to manage across different environments.

## Table of Contents

1. [ConfigMap Fundamentals](./01-configmap-fundamentals.md)
   - What are ConfigMaps
   - Creating ConfigMaps
   - Managing ConfigMap data

2. [Using ConfigMaps in Pods](./02-configmap-usage.md)
   - Environment Variables
   - Volume Mounts
   - Command-line arguments

3. [Secret Fundamentals](./03-secret-fundamentals.md)
   - What are Secrets
   - Types of Secrets
   - Creating and managing Secrets

4. [Using Secrets in Pods](./04-secret-usage.md)
   - Environment Variables
   - Volume Mounts
   - Security considerations

5. [Advanced Techniques](./05-advanced-techniques.md)
   - Projected Volumes
   - Immutable ConfigMaps and Secrets
   - Downward API integration
   - Enterprise Secrets Management

6. [Practical Exercises](./06-practical-exercises.md)
   - Real-world scenarios
   - CKAD-focused practice questions

## Key Concepts to Master for CKAD

- Creating, updating, and managing ConfigMaps and Secrets
- Different methods of creating ConfigMaps (literals, files, directories)
- Mounting ConfigMaps and Secrets in Pods
- Understanding the differences between ConfigMaps and Secrets
- Security best practices around sensitive data
- Efficiently updating applications when configuration changes

## Visual Learning Resources

Throughout this module, you'll find helpful diagrams illustrating:

- The relationship between ConfigMaps/Secrets and Pods
- Different mounting strategies
- Configuration update mechanisms
- Security considerations

## CKAD Exam Tips

- Know how to quickly create ConfigMaps and Secrets using imperative commands
- Understand the YAML structure for declarative creation
- Be able to troubleshoot common issues with configuration mounting
- Know how to update configurations and understand their impact on running applications

Let's begin our exploration of these essential Kubernetes objects!
