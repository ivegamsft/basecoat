---
name: backlog-rebalance-engine
description: "Use when syncing rebalanced backlog items into GitHub Project views and keeping item status aligned across boards. USE FOR: onboarding mapped work items into project boards after a rebalance plan is produced, updating existing project items idempotently without duplicate creation, aligning item status and grouping with the current rebalance plan, generating sync reports with added/updated/skipped counts, and preserving repo-specific delivery labels during sync. DO NOT USE FOR: writing implementation code, sprint retrospective analysis, or initial issue triage."
compatibility:
  - GHCP
capabilities:
  reasoning_depth: low
  tool_use: required
  context_window: small
  latency_profile: batch
  cost_tier: low
  safety_level: standard
model_policy:
  fallback: true
  preferred_families: [sonnet, haiku]
  upshift:
    allowed: true
    owner: runtime
    max_tier: reasoning
    triggers: [complexity, repeated_failures]
  cost_tracking:
    budget_tier: low
    chargeback_tag: backlog-rebalance-engine
---

# Backlog Rebalance Engine — Project Sync Skill

Use this skill to onboard mapped backlog items into GitHub Project views and keep item status
aligned with the current rebalance plan.

## Use Cases

- Sync rebalanced issues into a GitHub Project board after a sprint rebalance run.
- Detect existing project items and update their status instead of creating duplicates.
- Align status column (Todo / In Progress / Done) with issue open/closed state.
- Preserve delivery labels (sprint, wave, priority) on items during sync.
- Produce a sync report with counts of items added, updated, and skipped.

## Reference Files

| File | Purpose |
|---|---|
| [`references/project-sync-workflow.md`](references/project-sync-workflow.md) | Step-by-step workflow, idempotency rules, and output format |
| [`scripts/project-sync.sh`](scripts/project-sync.sh) | Bash script — idempotent add/update with sync report |
| [`scripts/project-sync.ps1`](scripts/project-sync.ps1) | PowerShell script — idempotent add/update with sync report |

## Sync Report Format

After each run:

```text
Sync complete: added=<n> updated=<n> skipped=<n>
```

- **added** — items inserted (not previously on the board).
- **updated** — items whose status field was changed.
- **skipped** — items already aligned; no change made.

## Idempotency Contract

A second run on unchanged data must report `added=0 updated=0`.

## Agent Pairing

- `backlog-burndown` — provides the rebalance plan and issue lists consumed by this skill.
- `sprint-project-mapper` — produces the grouped project mapping that drives sync targets.
- `sprint-planner` — provides sprint capacity and commitment context.
- `issue-triage` — surfaces blockers and label issues before sync.
