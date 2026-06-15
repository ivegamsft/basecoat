---
name: frontend-dev
description: "Use when building frontend components, responsive layouts, accessibility audits, or client-side state patterns with templates and review checklists. USE FOR: scaffold accessible UI component, review page for WCAG issues, design frontend state management, implement responsive layout behavior, audit frontend performance and correctness. DO NOT USE FOR: backend API design, database schema modeling, infrastructure provisioning."
compatibility:
  - GHCP
---
# Frontend Development Skill

Build UI components, implement responsive designs, audit accessibility compliance, and structure client-side state.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `component-spec-template.md` | Component specification: props, events, children, accessibility requirements, and all UI states |
| `accessibility-checklist.md` | WCAG 2.1 AA checklist organized by perceivable, operable, understandable, and robust |
| `state-management-template.md` | State structure: local state, shared state, async state, error/loading patterns |

## Agent Pairing

Use with `frontend-dev` agent. Components consume API contracts from `backend-dev`; route data schema questions to `data-tier` agent.
