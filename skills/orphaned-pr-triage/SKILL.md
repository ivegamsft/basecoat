---
name: orphaned-pr-triage
compatibility: [github-copilot-cli]
description: "Use when triaging stale pull requests and review backlog to keep repository flow healthy. USE FOR: identify orphaned PRs by inactivity windows, classify revive/close/escalate actions, draft maintainer comments for ownership handoff, and produce weekly cleanup reports with metrics. DO NOT USE FOR: implementing code changes, rewriting product requirements, or replacing security vulnerability triage."

invocation_rules:
  - "Use when PR queue hygiene, stale PR cleanup, or review ownership drift is requested."
visibility: "internal"
category: operations
---
# Orphaned PR Triage Skill

Use this skill to standardize stale PR cleanup and keep merge queues actionable.

## Reference Files

| File | Purpose |
|---|---|
| [`references/triage-checklist.md`](references/triage-checklist.md) | Candidate detection, bucketing, and action templates |

## Agent Pairing

- `orphaned-pr-cleanup`
- `issue-triage`
- `merge-coordinator`


