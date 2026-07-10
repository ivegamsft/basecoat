---
name: azure-linux-app-service
compatibility: [github-copilot-cli]
description: "Use when deploying or operating Python, Ruby, or Node.js apps on Azure App Service Linux. USE FOR: deploy a Flask or FastAPI app to App Service Linux, configure a startup command for a Node app, set up a deployment slot swap, stream Azure App Service logs, choose between code deploy and container deploy. DO NOT USE FOR: Windows App Service configuration, AKS ingress tuning, desktop app packaging."
category: infrastructure
metadata:
  category: infrastructure
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Azure Linux App Service

Deploy and operate Python, Ruby, and Node.js web applications on Azure App Service Linux.
Covers startup config, deployment slots, health checks, environment variables,
log streaming, and failure patterns.

## Reference Files

| File | Contents |
|------|----------|
| [`references/workflow.md`](references/workflow.md) | Runtime config, App Settings, health checks, deployment slots, container vs code deploy, log streaming |
| [`references/examples.md`](references/examples.md) | Python FastAPI and Node.js Express complete deployment examples |
| [`references/troubleshooting.md`](references/troubleshooting.md) | Common failure patterns: symptoms, causes, and fixes |

## Runtime Strings (Quick Reference)

| Language | `--linux-fx-version` |
|----------|---------------------|
| Python | `PYTHON\|3.11` |
| Ruby | `RUBY\|3.2` |
| Node.js | `NODE\|20-lts` |
