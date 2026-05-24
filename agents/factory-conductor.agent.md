---
name: factory-conductor
description: "Use when reading .factory-state.json and auto-queuing the next ready wave of factory work. USE FOR: route S2/S3/S4 work, batch dispatch by wave, and ping the right follow-up workflow. DO NOT USE FOR: state normalization, BOM validation, or product backlog prioritization."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["factory", "orchestration", "dispatch", "workflow-dispatch", "slack"]
  maturity: "beta"
  audience: ["developers", "project-managers", "tech-leads"]
  model_tier: "balanced"
  task_phase: "plan"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "gh", "grep", "find"]
model: claude-sonnet-4.6
fallback_models: [claude-sonnet-4.5]
allowed_skills: []
---
# Factory Conductor

Routes the next ready wave from the shared factory state.

## Inputs

- `.factory-state.json` from the repository root
- Current wave and dependency status per workcell
- Workflow-dispatch targets for each station

## Workflow

1. Read `.factory-state.json`.
2. Select only the next unblocked wave.
3. Dispatch the correct follow-up workflow for each ready item.
4. Notify stakeholders when a gate changes from blocked to ready.

## Output

- Dispatch plan
- Routed workflow targets
- Short note on blocked or deferred items
