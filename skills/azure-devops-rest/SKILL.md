---
name: azure-devops-rest
compatibility: [github-copilot-cli]
description: "Use when building automations that call Azure DevOps REST APIs for work items, pipelines, repos, and artifacts. USE FOR: query Azure DevOps work items via REST, trigger a pipeline run from a script, paginate Azure DevOps API results, authenticate with PAT or System.AccessToken, update a work item with JSON Patch. DO NOT USE FOR: GitHub REST automation, Azure resource deployment, browser UI test scripting."
category: infrastructure

context: fork
---
# Azure DevOps REST API Skill

Proven patterns for Azure DevOps REST API automation: auth, pagination, throttling, work items, pipelines, and repos.

## Reference Files

| File | Contents |
|------|----------|
| [`references/pipelines.md`](references/pipelines.md) | Auth (PAT + OIDC), API versioning, pagination, throttling, work items, repos, pipelines |
| [`references/extensions.md`](references/extensions.md) | Artifacts/packages, service hooks, extension development, common pitfalls |

## Auth Quick Reference

| Method | When to Use |
|--------|------------|
| PAT (Basic auth) | Scripts, local development |
| `System.AccessToken` / Managed Identity | Azure Pipelines, Azure-hosted automation |

Always use `api-version=7.1`. PAT expiry ≤ 90 days; store in Key Vault.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Wrong Content-Type on PATCH | Use `application/json-patch+json` |
| Missing `api-version` | Always include `?api-version=7.1` |
| Unhandled 429 | Check `Retry-After` header; exponential backoff |
| No pagination | Always check `x-ms-continuationtoken` |

## Key Limits

- WIQL: max 20,000 work item IDs
- Batch get: max 200 IDs per request
- Default page size: ~200 items (use `$top`)
