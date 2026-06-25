---
name: app-inventory
compatibility: [github-copilot-cli]
description: "Use when inventorying legacy applications to capture dependencies, service bindings, framework versions, and migration complexity. USE FOR: inventory a legacy application portfolio, scan app dependencies and connection strings, assess migration complexity for an app, create an application inventory report, map external service bindings before modernization. DO NOT USE FOR: rewriting application code, deploying workloads, designing the target-state architecture."

category: architecture
---

# App Inventory Skill

Reusable templates and workflows for inventorying legacy application portfolios — producing audit-ready output for migration planning and sprint estimation.

## Reference Files

| File | Contents |
|------|----------|
| [`references/workflow-guide.md`](references/workflow-guide.md) | 5-step inventory workflow, downstream agent routing, related assets |

## Templates in This Skill

| File | Purpose |
|------|---------|
| `inventory-report-template.md` | Markdown report for architecture reviews and stakeholders |
| `complexity-scoring-template.md` | Scoring worksheet to derive migration complexity score |

## Paired Agent

`agents/basecoat-10-core-app-inventory.agent.md` — see `docs/treatment-matrix.md` for app disposition decisions.


