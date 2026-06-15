---
name: container-migration
description: "Scaffold containerization of a legacy app for Azure Container Apps or Kubernetes with Dockerfile, health probes, and deployment assets. USE FOR: containerize this legacy app, create a Dockerfile for production, migrate app to Azure Container Apps, add Kubernetes manifests and health checks, set up ACR build and push workflow. DO NOT USE FOR: simple VM deployment without containers, tuning application business logic, non-container desktop packaging."
compatibility:
  - GHCP
---
# Container Migration

Scaffold containerization of a legacy application targeting Azure Container Apps (ACA),
Azure Kubernetes Service (AKS), or an ACR-only workflow.

## Reference Files

| File | Contents |
|------|----------|
| [`references/inputs.md`](references/inputs.md) | Input parameters and base images per stack |
| [`references/workflow.md`](references/workflow.md) | Multi-stage Dockerfile, /healthz stubs, ACR workflow, Bicep module, K8s manifests |
| [`references/patterns.md`](references/patterns.md) | Anti-patterns and related skills |

## Base Images (Quick Reference)

| Stack | Runtime image |
|-------|--------------|
| dotnet | `mcr.microsoft.com/dotnet/aspnet:8.0` |
| python | `python:3.12-slim` |
| java | `eclipse-temurin:21-jre-alpine` |
| node | `node:20-slim` |
| ruby | `ruby:3.3-slim` |
