---
name: factory-state-machine
description: "Use when defining factory state transitions, reading or writing .github/factory-state.json, or orchestrating workcell workflow gates. USE FOR: intake/complete/pending transitions, auto-proceed rules, escalation checks, and state validation. DO NOT USE FOR: general app state management or unrelated workflow docs."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# Factory State Machine Skill

Model and validate factory state transitions for orchestration workflows.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `factory-state-template.json` | Starter `.github/factory-state.json` with states, transitions, and escalation rules |

## Core Rules

- Keep the state file as the single source of truth.
- Model each transition explicitly; do not infer hidden hops.
- Separate automatic transitions from human escalation.
- Make terminal states and rollback states obvious.
- Keep state names and conditions deterministic so workflows can read them safely.

## Agent Pairing

Use with factory orchestration agents that read `.github/factory-state.json` and trigger Workcell workflows.
