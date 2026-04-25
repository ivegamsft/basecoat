---
name: frontend-dev
description: "Use when building UI components, implementing responsive layouts, auditing accessibility, or designing state management. Provides component spec, accessibility checklist, and state management templates."
---

# Frontend Development Skill

Use this skill when the task involves building UI components, implementing responsive designs, auditing accessibility compliance, or structuring client-side state.

## When to Use

- Scaffolding a new UI component with props, states, and accessibility requirements
- Auditing a component or page against WCAG 2.1 AA
- Designing a state management structure for a feature
- Reviewing a frontend implementation for accessibility, performance, or correctness

## How to Invoke

Reference this skill by attaching `skills/frontend-dev/SKILL.md` to your agent context, or instruct the agent:

> Use the frontend-dev skill. Apply the component spec template and accessibility checklist to every component being built or reviewed.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `component-spec-template.md` | Component specification: props, events, children, accessibility requirements, and all UI states |
| `accessibility-checklist.md` | WCAG 2.1 AA checklist organized by perceivable, operable, understandable, and robust principles |
| `state-management-template.md` | State structure template covering local state, shared state, async state, and error/loading patterns |

## Agent Pairing

This skill is designed to be used alongside the `frontend-dev` agent. The agent drives the workflow; this skill provides the reference templates and audit checklists.

Frontend components consume API contracts defined by the `backend-dev` agent. Route data schema questions to the `data-tier` agent.
