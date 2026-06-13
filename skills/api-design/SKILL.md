---
name: api-design
description: "Use when designing or reviewing API contracts, versioning decisions, and governance standards. USE FOR: design a REST API contract, review an OpenAPI diff for breaking changes, choose an API versioning strategy, draft GraphQL schema changes, create a deprecation or sunset plan. DO NOT USE FOR: implementing request handlers, tuning database indexes, penetration testing an API."
compatibility: GHCP
---

# API Design Skill

Design new API contracts, review spec changes for breaking changes, choose versioning strategies, and enforce API governance standards.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `openapi-template.md` | OpenAPI 3.x skeleton for a new REST API resource with CRUD, pagination, and error envelopes |
| `breaking-change-checklist.md` | Checklist for evaluating whether a spec change is breaking, with mitigation guidance |
| `versioning-decision-tree.md` | Decision tree for choosing the right versioning action for a given change |
| `api-governance-checklist.md` | Governance checklist every API spec must pass before approval |

## Agent Pairing

Use with `api-designer` agent. For implementation hand off to `backend-dev`; for data models coordinate with `data-tier`; share the spec with `frontend-dev` for consumer integration.
