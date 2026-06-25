---
name: backend-dev
compatibility: [github-copilot-cli]
description: "Use when implementing backend APIs, business logic, service layers, or repository-based data access. USE FOR: implement a REST endpoint, scaffold a service layer, define an error response catalog, add repository pattern data access, review backend logic for correctness. DO NOT USE FOR: frontend component styling, infrastructure provisioning, enterprise architecture strategy."
---
# Backend Development Skill

Design and implement backend services, REST or GraphQL APIs, business logic layers, and database access patterns.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `api-spec-template.md` | OpenAPI 3.x-compatible skeleton for a new API resource |
| `service-template.md` | Service layer scaffold with dependency injection, error handling, and logging stubs |
| `error-catalog-template.md` | Structured error catalog with codes, messages, HTTP status codes, and resolution hints |
| `repository-pattern-template.md` | Data access repository pattern, adaptable to any ORM or query builder |

## Agent Pairing

Use with `backend-dev` agent. For full-stack features, backend contracts are consumed by `frontend-dev`; route data persistence to `data-tier` agent.
