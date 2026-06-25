---
name: devops
compatibility: [github-copilot-cli]
description: "Use when designing CI/CD pipelines, infrastructure as code, deployment workflows, rollback plans, or observability setup. USE FOR: create GitHub Actions pipeline, review Bicep or Terraform deployment templates, define release promotion gates, write rollback runbook for a service, add monitoring and health checks for deployment. DO NOT USE FOR: writing application feature code, database schema modeling, drafting product marketing copy."
---
# DevOps Skill

CI/CD pipeline design, infrastructure as code, deployment workflows, rollback planning, and observability configuration.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `github-actions-template.md` | GitHub Actions workflow skeleton with build, test, scan, and deploy stages |
| `deployment-checklist.md` | Pre-deployment and post-deployment verification checklist |
| `rollback-runbook-template.md` | Step-by-step rollback runbook template with decision criteria |
| `environment-promotion-template.md` | Environment promotion path definition with gates and approval rules |

## Related Guardrails

| Guardrail | When to apply |
|---|---|
| [`references/runner-routing.md`](references/runner-routing.md) | Choosing self-hosted vs GitHub-hosted runners; routing patterns and fallback strategy |

## Agent Pairing

Use with `devops-engineer` agent. For app concerns pair with `backend-dev` or `frontend-dev`; route database migrations to `data-tier` agent.


