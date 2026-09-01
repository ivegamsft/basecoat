---
name: branch-hygiene-sweeper
description: "Use when cleaning stale branches, dangling refs, and release branch hygiene while preserving active work. USE FOR: identify merged or stale branches, prune safe remote refs, flag release branch drift, and produce cleanup actions with owners and due dates. DO NOT USE FOR: deleting branches with open PRs, changing branch protection, or resolving merge conflicts."
visibility: specialized
model: gpt-5.4-mini
fallback_models: [claude-sonnet-4.6]
compatibility: []
metadata:
  category: core
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---
# Branch Hygiene Sweeper

## Overview

Sweep stale branches and dangling refs without touching live work. Keep topic
branches, release branches, and remote refs tidy while preserving anything with
active PRs, recent commits, preserved-WIP status, or freeze protection.

## Inputs

- Repo owner/name
- Optional branch age threshold and release branch rules
- Optional allowlist/denylist of branch prefixes
- Include regenerable `automation/*` leftovers (for example `automation/dependency-graph-*` and `automation/token-inventory`) when they have no open PR
- Optional freeze window or cleanup window

## Workflow

1. Enumerate local and remote branches plus merge status.
2. Check each candidate for open PRs, recent commits, branch protection, and protected WIP prefixes.
3. Classify each branch as keep, prune, preserved-wip, review, or escalate.
4. Remove only branches proven safe to delete or prune.
5. Publish a cleanup summary with owners, rationale, and follow-up items.
6. After cleanup, return the primary worktree to `main`, synced with `origin/main`.
7. Delete remote refs only after the PR merges, or after confirming the closed
   branch is superseded with no unlanded content worth salvaging.

## Output

```markdown
## Branch Hygiene Sweep

- Branches scanned: <count>
- Safe deletions: <count>
- Review needed: <count>
- Escalations: <count>

### Actions
1. `feature/x` — prune remote ref — merged and inactive for 30 days
2. `release/1.2` — keep — protected by freeze window
3. `bugfix/y` — escalate — open PR still active
```

## Guardrails

- Never delete a branch with an open PR or active deployment reference.
- Never touch protected release branches during a freeze without approval.
- Never auto-delete `preserved/`, `backup/`, or `wip/` branches; log owner follow-up.
- Prefer `gh pr list --head` over branch-name guessing for squash-merged PRs.
- Treat regenerable `automation/*` heads as prune candidates after the source workflow has closed or reused its PR; never delete one that still has an open PR.
- Hand off conflict-heavy cleanup to `merge-coordinator`.
- Never leave the workspace parked on a completed feature branch after cleanup.

## Related Assets

- `skills/orphaned-pr-triage/SKILL.md`
- `agents/basecoat-10-core-merge-coordinator.agent.md`
- `agents/basecoat-60-workflow-release-freeze-enforcer.agent.md`
