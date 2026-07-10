---
name: decision-log-capture
compatibility: [github-copilot-cli]
description: "Use when capturing ceremony outcomes into durable decision records. USE FOR: document decision, rationale, options considered, owner, and follow-up actions from standup, sprint, and release ceremonies. DO NOT USE FOR: writing implementation code, replacing full ADR workflows, or generating marketing content."

invocation_rules:
  - "Use when meeting or ceremony outcomes must be persisted with explicit ownership."
visibility: "internal"
category: architecture
metadata:
  category: architecture
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Decision Log Capture Skill

Use this skill to create consistent, auditable decision records from ceremonies.

## Reference Files

| File | Purpose |
|---|---|
| [`references/decision-log-template.md`](references/decision-log-template.md) | Lightweight decision record template |

## Agent Pairing

- `release-readiness-chair`
- `daily-standup-facilitator`
- `sprint-closeout-auditor`
