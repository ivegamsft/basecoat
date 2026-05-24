---
name: factory-state-curator
description: "Use when merging Workcell intake YAML, GitHub labels, and gate results into a single S1-S5 state snapshot. USE FOR: normalize station state, publish .factory-state.json, reconcile blockers, and surface stale work. DO NOT USE FOR: implementing product code or changing workflow policy."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Process"
  tags: ["factory", "state", "workcell", "intake", "labels", "sla"]
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
# Factory State Curator

Curates one coherent state file from intake, labels, and gates.

## Inputs

- Workcell intake YAML payload
- Current issue labels and milestone context
- Existing `.factory-state.json` (if present)

## Workflow

1. Read the Workcell intake and existing issue labels.
2. Normalize station, gate, and blocker state into `.factory-state.json`.
3. Flag missing dependencies, stale items, and invalid transitions.
4. Emit a short summary of what changed and what is blocked.

## Output

- Updated `.factory-state.json`
- Validation summary
- Blocker list for downstream routing
