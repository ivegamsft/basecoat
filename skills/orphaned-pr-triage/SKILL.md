---
name: orphaned-pr-triage
compatibility: [github-copilot-cli]
description: "Use when triaging stale pull requests and review backlog to keep repository flow healthy. USE FOR: identify orphaned PRs by inactivity windows, classify revive/close/escalate actions, draft maintainer comments for ownership handoff, and produce weekly cleanup reports with metrics. DO NOT USE FOR: implementing code changes, rewriting product requirements, or replacing security vulnerability triage."

invocation_rules:
  - "Use when PR queue hygiene, stale PR cleanup, or review ownership drift is requested."
visibility: "internal"
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Orphaned PR Triage Skill

Use this skill to standardize stale PR cleanup and keep merge queues actionable.

## Reference Files

| File | Purpose |
|---|---|
| [`references/triage-checklist.md`](references/triage-checklist.md) | Candidate detection, bucketing, and action templates |
| [`../backlog-revalidation/references/classification-contract.md`](../backlog-revalidation/references/classification-contract.md) | Shared issue/PR revalidation classes and evidence contract |

## Agent Pairing

- `orphaned-pr-cleanup`
- `issue-triage`
- `backlog-revalidation` for evidence-based classification of old PRs (inactivity is a filter, not a close reason)
- `merge-coordinator`
