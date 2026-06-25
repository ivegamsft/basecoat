---
name: change-isolation
compatibility: [github-copilot-cli]
description: "Use when designing or reviewing monorepo workflow isolation so independent layers (mobile, database, portal, extension, infra) can build, test, and release separately. USE FOR: define path-based lane boundaries, isolate deploy workflows by layer, design independent versioning lanes, audit cross-trigger coupling in GitHub Actions, create release lane contracts. DO NOT USE FOR: implementing application feature logic, writing database queries unrelated to CI/CD boundaries, or generic project planning without workflow scope."
---
# Change Isolation Skill

Design and enforce CI/CD boundaries so different layers can evolve and release independently.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `layer-boundary-matrix-template.md` | Defines layer-to-path ownership, lane names, and dependency directions |
| `workflow-path-filter-checklist.md` | PR review checklist to verify trigger isolation and prevent cross-layer coupling |
| `release-lane-contract-template.md` | Standard contract for versioning, promotion, and rollback per layer |

## Agent Pairing

Use with `change-isolation-architect` agent. For implementation details pair with `devops-engineer`; for schema change lanes pair with `data-tier`; for app/UI lanes pair with `frontend-dev`.
