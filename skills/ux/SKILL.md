---
name: ux
compatibility: [github-copilot-cli]
description: "Use when defining or assessing user journeys, wireframes, component behavior, or accessibility expectations at the experience level. USE FOR: map end-to-end user journey, create wireframe spec for new screen, assess design states and interactions, assess journey accessibility, evaluate usability of a workflow. DO NOT USE FOR: findings-only code or PR review (frontend-audit), frontend implementation or remediation (frontend-dev), backend infrastructure design."
category: development
metadata:
  category: development
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# UX Design Skill

Design user experiences, map user journeys, specify UI wireframes and components, and audit designs for accessibility and usability.

## Activation Boundary

This skill is primary for experience-level assessment, including usability and
accessibility of journeys or wireframes. `frontend-audit` is primary for
findings-only review of implemented code; `frontend-dev` owns code changes.
Assessment alone does not authorize implementation. Preserve explicit
composition when the user asks for experience assessment and implementation:
produce the experience findings or spec, then hand off the requested code work.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `user-journey-template.md` | End-to-end user journey with personas, steps, emotions, and opportunities |
| `wireframe-spec-template.md` | Screen-level wireframe spec with layout, content hierarchy, and interaction states |
| `accessibility-audit-checklist.md` | WCAG 2.1 AA compliance checklist organized by principle |
| `component-spec-template.md` | Figma-compatible component spec with anatomy, variants, states, spacing, and accessibility |

## Agent Pairing

Use with `ux-designer` agent. Specs produced here are consumed by `frontend-dev`; route accessibility violations back to `ux-designer` then to `frontend-dev` for fixes.
