---
name: git-worktrees
compatibility: [github-copilot-cli]
description: "Use when isolating parallel tasks, experiments, or hotfixes into separate working directories. USE FOR: create isolated workspace for feature branch, run parallel tasks without stashing, set up clean environment for risky experiment, manage multiple branches simultaneously, clean up stale worktrees. DO NOT USE FOR: simple branch switching, single-task linear workflows, repos with submodule-heavy setups that complicate worktrees."
category: infrastructure
---
# Git Worktrees — Isolated Parallel Workspaces

## When to Use

- Parallel tasks (orchestrator dispatching to subagents)
- Risky experiments that should not affect the main working directory
- Hotfixes needed while a feature branch is mid-work

## When NOT to Use

- Simple linear workflows — just use branches
- Repos with complex submodule setups

## Workflow

1. **Create**: `git worktree add ../<repo>-wt-<issue-or-pr> -b <type>/<issue>-<short-name>`
2. **Setup**: `cd ../<repo>-wt-<issue-or-pr> && npm install && npm test` (verify clean baseline)
3. **Work**: Changes stay isolated; main directory untouched
4. **Cleanup**: `git worktree remove ../<repo>-wt-<issue-or-pr> && git worktree prune`

Example:

`git worktree add ../basecoat-wt-1306 -b feat/1301-workflow-distribution`

## Safety Rules

- Always verify a clean test baseline before starting work.
- Never delete a worktree directory manually — use `git worktree remove`.
- Run `git worktree list` before creating new ones.
- Each worktree must be on a unique branch.
- Prefix worktree paths as `<repo>-wt-<issue-or-pr>` for discoverability and cleanup.
