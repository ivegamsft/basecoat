---
name: architecture
description: "Use when shaping system architecture, documenting decisions, and evaluating cross-cutting tradeoffs. USE FOR: design a system architecture, create a C4 diagram, write an ADR for a platform choice, compare technology options with a matrix, assess architectural risks and mitigations. DO NOT USE FOR: implementing endpoints, fixing CI failures, pixel-perfect UI design."
---

# Architecture Skill

System design, architecture documentation, technology evaluation, and risk assessment at the architecture level.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `adr-template.md` | Architecture Decision Record with status lifecycle, context, decision, and consequences |
| `c4-diagram-template.md` | C4 context and container diagram templates in Mermaid syntax |
| `tech-selection-matrix-template.md` | Weighted scoring matrix for evaluating technology alternatives |
| `risk-register-template.md` | Architecture risk register with likelihood, impact, and mitigation tracking |

## Agent Pairing

Use with `solution-architect` agent. Hand off to `backend-dev` for API/service design, `frontend-dev` for UI architecture, `data-tier` for database and storage design.
