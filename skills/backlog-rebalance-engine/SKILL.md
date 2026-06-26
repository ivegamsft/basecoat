---
name: backlog-rebalance-engine
compatibility: [github-copilot-cli]
description: "Use when syncing rebalanced backlog items into GitHub Project views with deterministic status/metadata updates. USE FOR: idempotent project item add-or-update, status alignment, priority/sprint/wave mutation with policy checks, and rollback/change-log artifact generation. DO NOT USE FOR: implementation coding, sprint retrospectives, or initial issue triage."
category: workflow

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
and delivery metadata aligned with the current rebalance plan.

## Use Cases

- Sync rebalanced issues into a GitHub Project board after a sprint rebalance run.
- Update existing project items instead of creating duplicates.
- Apply policy-validated metadata mutations for `priority:*`, `sprint:*`, and `wave:*`.
- Emit sync summary plus rollback and reason-coded change log artifacts.

## Reference Files

| File | Purpose |
|---|---|
| [`references/project-sync-workflow.md`](references/project-sync-workflow.md) | Contract and workflow |
| [`scripts/project-sync.sh`](scripts/project-sync.sh) | Bash implementation |
| [`scripts/project-sync.ps1`](scripts/project-sync.ps1) | PowerShell implementation |

## Metadata Mutation Contract

- Allowed families: `priority:*`, `sprint:*`, `wave:*`, plus project `Status`.
- Deterministic apply: remove existing family labels, then add one target label.
- Validation before apply: `priority:(critical|high|medium|low)`, `sprint:<number>`, `wave:<number>`.
- Freeze mode blocks metadata label writes unless an explicit override is supplied.
- Each issue includes reason codes (for example `ADD_TO_PROJECT`, `STATUS_MISMATCH`, `METADATA_MUTATION_PRIORITY`, `POLICY_FREEZE_WINDOW_BLOCK`).

## Sync Report Format

After each run:

```text
Sync complete: added=<n> updated=<n> skipped=<n>
```

- **added** — items inserted (not previously on the board).
- **updated** — items whose status field was changed.
- **skipped** — items already aligned; no change made.

- Rollback artifact (JSON) with inverse operations for applied mutations.
- Change log (JSON) with per-item reason codes and mutation decisions.

## Idempotency Contract

A second run on unchanged data must report `added=0 updated=0`.
