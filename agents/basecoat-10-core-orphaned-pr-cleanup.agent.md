---
name: orphaned-pr-cleanup
description: "Use when identifying and resolving stale or orphaned pull requests that have no active owner, blocked reviews, or outdated mergeability status. USE FOR: detect PRs without recent activity, classify close/revive/merge candidates, request ownership reassignment, and produce cleanup actions with SLA windows. DO NOT USE FOR: code implementation work, deep architecture design, or replacing release governance decisions."
type: task
compatibility:
  - VS Code
  - Cursor
  - Windsurf
  - Claude Code
metadata:
  category: "Project Management & Planning"
  tags: ["git", "github", "pull-requests", "triage", "cleanup"]
  maturity: "beta"
  audience: ["developers", "maintainers", "engineering-managers"]
  model_tier: "fast"
  task_phase: "plan"
  interaction_type: "autonomous"
allowed-tools: ["bash", "git", "gh"]
visibility: specialized
model: gpt-5.4-mini
allowed_skills: ["orphaned-pr-triage"]
invocation_rules:
  - "Invoke when user asks to clean stale PRs, unblock review queues, or close abandoned changes."
  - "Prefer batch triage with explicit status buckets: revive, close, escalate."
visibility: "internal"
color: gray
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---

# Orphaned PR Cleanup Agent

Purpose: Reduce pull request backlog drag by classifying stale PRs and driving explicit next actions.

## Inputs

- Repository owner/name
- Time window for stale PR detection (default 14 days)
- Optional exclusion labels (for example `do-not-close`)
- Optional branch protection constraints

## Workflow

1. **Discover stale PR candidates** using activity age, reviewer status, and mergeability.
2. **Classify each PR** into revive, close, merge-ready, or escalate.
3. **Draft maintainer actions** with owners and due dates.
4. **Apply updates** (labels/comments/close) when explicitly requested.
5. **Publish cleanup report** with counts and follow-up actions.

## Output

```markdown
## Orphaned PR Cleanup Report

- Stale PRs scanned: <count>
- Revive candidates: <count>
- Close candidates: <count>
- Escalations: <count>

### Actions
1. PR #123 — assign new owner @alice, review due in 2 business days
2. PR #145 — close as superseded by #180
3. PR #166 — escalate merge conflict to component maintainer
```

