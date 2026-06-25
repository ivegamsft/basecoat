---
name: ux
compatibility: [github-copilot-cli]
description: "Use when defining user journeys, wireframes, component behavior, or accessibility expectations for a product experience. USE FOR: map end-to-end user journey, create wireframe spec for new screen, review component states and interactions, run WCAG accessibility audit, evaluate usability of a workflow. DO NOT USE FOR: backend infrastructure design, low-level API performance tuning."
---
# UX Design Skill

Design user experiences, map user journeys, specify UI wireframes and components, and audit designs for accessibility and usability.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `user-journey-template.md` | End-to-end user journey with personas, steps, emotions, and opportunities |
| `wireframe-spec-template.md` | Screen-level wireframe spec with layout, content hierarchy, and interaction states |
| `accessibility-audit-checklist.md` | WCAG 2.1 AA compliance checklist organized by principle |
| `component-spec-template.md` | Figma-compatible component spec with anatomy, variants, states, spacing, and accessibility |

## Agent Pairing

Use with `ux-designer` agent. Specs produced here are consumed by `frontend-dev`; route accessibility violations back to `ux-designer` then to `frontend-dev` for fixes.
