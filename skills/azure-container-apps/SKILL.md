---
name: azure-container-apps
compatibility: [github-copilot-cli]
title: Azure Container Apps Deployment & Operations
description: "Use when deploying or operating containerized workloads on Azure Container Apps with scaling, revisions, and Dapr. USE FOR: deploy an app to Azure Container Apps, configure a Dapr sidecar, set Azure Container Apps scaling rules, manage revisions and traffic splitting, create a container apps job. DO NOT USE FOR: AKS cluster administration, App Service troubleshooting, virtual machine sizing."
---
# Azure Container Apps Skill

Deploy and operate containerized workloads on ACA with Dapr, revision management, and KEDA-based scaling.

## Reference Files

| File | Contents |
|------|----------|
| [deployment-patterns.md](references/deployment-patterns.md) | Basic deployment, ACR + managed identity, image management |
| [dapr-integration.md](references/dapr-integration.md) | Dapr sidecars, state management, service invocation |
| [scaling-rules.md](references/scaling-rules.md) | HTTP, KEDA, Event Hub, and custom metric scaling |
| [revision-management.md](references/revision-management.md) | Revisions, traffic splitting, blue-green deploys |
| [ingress-configuration.md](references/ingress-configuration.md) | External/internal ingress, TLS, custom domains |
| [managed-identity.md](references/managed-identity.md) | System/user identities, role assignment, Key Vault access |
| [health-probes.md](references/health-probes.md) | Liveness, readiness, startup probes (CLI/YAML/Bicep) |
| [container-apps-jobs.md](references/container-apps-jobs.md) | Scheduled and event-driven jobs, job scaling |
| [multi-container-environments.md](references/multi-container-environments.md) | Environment setup, internal service communication |
