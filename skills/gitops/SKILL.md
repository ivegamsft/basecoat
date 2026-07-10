---
name: gitops
compatibility: [github-copilot-cli]
description: "Use when designing or reviewing GitOps workflows with Flux or ArgoCD, declarative delivery, drift reconciliation, and secrets management across clusters. USE FOR: set up Flux or ArgoCD workflow, structure multi-environment cluster config, handle Kubernetes drift reconciliation, choose GitOps secrets pattern, review pull-based deployment practices. DO NOT USE FOR: manual kubectl runbooks, non-Kubernetes CI pipelines, imperative server configuration."
category: infrastructure
metadata:
  category: infrastructure
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# GitOps

GitOps uses Git as the single source of truth for infrastructure and application state.
The operator continuously reconciles actual cluster state with declared desired state.

## Quick Navigation

| Reference | Contents |
|---|---|
| [references/flux-argocd.md](references/flux-argocd.md) | Flux and ArgoCD installation, configuration, multi-environment promotion |
| [references/multi-cluster-secrets.md](references/multi-cluster-secrets.md) | Multi-cluster topology, secrets management (ESO, Sealed Secrets, Kyverno), reconciliation monitoring |

## Core Principles

- **Declarative** — desired state in Git, not imperative commands
- **Versioned & Immutable** — all changes tracked in Git history
- **Pulled, not Pushed** — operators pull from Git; CI/CD does not push to clusters
- **Continuously Reconciled** — operator detects drift and auto-corrects

## Best Practices

- Separate config by environment (`clusters/prod/`, `clusters/staging/`)
- Pin explicit image versions — never use `latest`
- Require PR approval before merging cluster config changes
- Never run `kubectl apply` manually — commit and let the operator apply
