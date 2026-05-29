---
description: "Compatibility alias for intent prefix routing. Preserves the legacy filename while the prefixed BaseCoat instruction is the canonical source."
applyTo: "**/*"
---

# Intent Prefix Routing

This legacy alias mirrors `basecoat-10-core-intent-routing.instructions.md`.
Keep it in sync so older references still receive the full routing guidance.

## Enforcement Contract

Prefix parsing is a hard contract, not a soft hint. When a recognized prefix
appears at the start of a message, it must be interpreted as an authoritative
routing signal before any plain-text interpretation occurs.

## Prefix Vocabulary

| Prefix | Intent | Default timing | Primary agents |
|---|---|---|---|
| `feature:` | New capability or enhancement | Later | `@sprint-planner`, `@solution-architect` |
| `refactor:` | Structural improvement, no behavior change | Later | `@code-review`, `@performance-analyst` |
| `architect:` | Architecture design or system-design decision | Later | `@solution-architect` |
| `azure:` | Azure-scoped operation | Now | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change | Now | `@devops-engineer`, `@solution-architect` |

## Plan-First Enforcement

For any implementation intent that touches multiple files or requires design
decisions, planning is required before execution begins.

Affected prefixes: `feature:`, `refactor:`, `architect:`

## Sprint-Style Request Nudge

When the user asks to plan and execute the next sprint or use similar
sprint-planning language, route to `@sprint-planner` first and wait for
confirmation before execution.

## Azure Preflight Guardrail

For `azure:` and `infra:` work, review these compatibility aliases before
proceeding:

- `instructions/ci-firewall.instructions.md`
- `instructions/rbac-authentication.instructions.md`
