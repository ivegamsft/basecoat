---

name: git-worktrees
description: "Use when isolating parallel tasks, experiments, or hotfixes into separate working directories. USE FOR: create isolated workspace for feature branch, run parallel tasks without stashing, set up clean environment for risky experiment, manage multiple branches simultaneously, clean up stale worktrees. DO NOT USE FOR: simple branch switching, single-task linear workflows, repos with submodule-heavy setups that complicate worktrees."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Developer Workflow"
  tags: ["git", "parallelism", "isolation", "branching"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git"]

---

# Git Worktrees — Isolated Parallel Workspaces

Git worktrees allow multiple working directories linked to the same repository,
each on a different branch. This eliminates stashing, context-switching overhead,
and cross-contamination between parallel tasks.

## When to Use

- Running multiple tasks in parallel (orchestrator dispatching to subagents)
- Risky experiments that should not affect the main working directory
- Hotfixes needed while a long-running feature branch is mid-work
- Comparing behavior across branches side-by-side
- CI reproduction in a clean state without disturbing local changes

## When NOT to Use

- Simple linear workflows (one task at a time, just use branches)
- Repos with complex submodule setups (worktrees + submodules can conflict)
- When disk space is constrained (each worktree is a full checkout)

## Workflow

### Create an Isolated Workspace

```bash
# Create worktree on a new feature branch
git worktree add ../project-feature-name -b feat/feature-name

# Or checkout an existing branch
git worktree add ../project-hotfix origin/hotfix/urgent-fix
```

### Set Up the Environment

```bash
cd ../project-feature-name

# Install dependencies (the worktree is a full working directory)
npm install        # or pip install -r requirements.txt, etc.

# Verify clean test baseline BEFORE making changes
npm test           # All tests must pass in the fresh worktree
```

### Work in Isolation

- Make changes in the worktree directory independently.
- The main working directory remains untouched.
- Commits in the worktree go to its branch as normal.

### Merge and Clean Up

```bash
# After work is complete and merged
cd /path/to/main/repo
git worktree remove ../project-feature-name

# Prune stale worktree references
git worktree prune
```

## Common Patterns

### Orchestrator Multi-Task Dispatch

When an orchestrator dispatches 3 parallel tasks:

```bash
git worktree add ../task-1 -b feat/task-1
git worktree add ../task-2 -b feat/task-2
git worktree add ../task-3 -b feat/task-3
```

Each subagent works in its own worktree. After completion, the orchestrator
merges results back to the integration branch.

### Hotfix While Feature In Progress

```bash
# Main worktree has feature work in progress (uncommitted changes)
git worktree add ../hotfix -b hotfix/critical-bug origin/main
cd ../hotfix
# Fix, test, push, PR, merge — without touching feature work
git worktree remove ../hotfix
```

## Safety Rules

- Always verify a clean test baseline in a new worktree before starting work.
- Never delete a worktree directory manually — use `git worktree remove`.
- Run `git worktree list` to see all active worktrees before creating new ones.
- Each worktree must be on a unique branch (git enforces this).
