---
name: backlog-burndown
compatibility: [github-copilot-cli]
description: "Use when managing backlog burn-down and flow health across a sprint window or milestone. USE FOR: build burn-down tables from issue and open-PR state changes, detect spillover risk from velocity and remaining scope, prioritize blockers to protect sprint goals, and produce daily backlog status updates with explicit actions. DO NOT USE FOR: writing implementation code, replacing sprint retrospective analysis, or setting annual portfolio strategy."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Backlog Burndown Skill

Use this skill when you need a structured way to track backlog completion pace, scope drift, and risk to sprint commitments.

## Use Cases

- Daily burn-down check for sprint backlog health.
- Mid-sprint risk review for scope creep and blocked work.
- End-of-week status update with actionable backlog triage recommendations.
- Combined issue-and-open-PR burn-down so in-flight PRs count toward remaining scope.

## Reference Files

| File | Purpose |
|---|---|
| [`references/burndown-workflow.md`](references/burndown-workflow.md) | Step-by-step workflow and report format |
| [`references/metrics-formulas.md`](references/metrics-formulas.md) | Formulas for burn-down, spillover, and blocker pressure |

## Agent Pairing

- `sprint-planner` for commitment and capacity context.
- `issue-triage` for blocker and priority updates.
- `orphaned-pr-cleanup` for open-PR state, mergeability, and stale-PR triage.
- `product-manager` for scope trade-off decisions.
