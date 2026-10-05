---
name: frontend-dev
compatibility: [github-copilot-cli]
description: "Use when building or remediating frontend components, responsive layouts, accessibility violations, or client-side state patterns. USE FOR: scaffold accessible UI component, fix reported WCAG issues, design frontend state management, implement responsive layout behavior, remediate frontend performance findings. DO NOT USE FOR: findings-only frontend review (frontend-audit), experience-level usability assessment (ux), backend API design, infrastructure provisioning."
category: development
metadata:
  category: development
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Frontend Development Skill

Build UI components, implement responsive designs, remediate accessibility findings, and structure client-side state.

## Activation Boundary

For findings-only review of existing code, use `frontend-audit` as primary.
For journey, wireframe, or experience-level assessment, use `ux` as primary.
This skill owns implementation and remediation, including verification of its fixes.
An audit request alone does not authorize edits. Preserve explicit composition:
when asked to audit and fix, audit first, then implement only the requested fixes.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `component-spec-template.md` | Component specification: props, events, children, accessibility requirements, and all UI states |
| `accessibility-checklist.md` | WCAG 2.1 AA checklist organized by perceivable, operable, understandable, and robust |
| `state-management-template.md` | State structure: local state, shared state, async state, error/loading patterns |

## Agent Pairing

Use with `frontend-dev` agent. Components consume API contracts from `backend-dev`; route data schema questions to `data-tier` agent.
