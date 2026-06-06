---
description: "Git workflow, branch naming, commit conventions, and Copilot agent triggers"
applyTo: ".github/**/*,*.md"
---

# Workflow Conventions

## Branch and Commit Conventions

- Branches: `<type>/<issue-number>-<short-description>` (e.g., `feat/1334-split-instructions`)
- Commits: `<type>(<scope>): <summary>` (conventional commits)
- Always include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer

Example:

```bash
git checkout -b feat/1334-split-instructions
git add . && git commit -m "feat(instructions): split monolithic copilot-instructions.md into 7 targeted files

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## PR Workflow

Standard pattern for all changes:

```bash
git checkout -b <type>/<issue>-<desc>
git add . && git commit -m "<type>(<scope>): <summary>"
gh auth switch --user ibuyspy
git push origin <branch>
gh pr create --title "<title>" --body "<body>"
gh pr merge --squash --admin
```

Use `--admin` to bypass CI wait when change is pre-validated locally.

## Fleet Merge Pacing

During fleet or burndown sessions, enforce serialized merge pacing:

1. Queue work in parallel if needed, but merge one PR at a time.
2. Before each merge, confirm required checks are green and mergeability is clean.
3. Wait for merge completion before starting the next merge.
4. After each merge, clean up local and remote branch state before continuing.

## Triggering the Copilot Coding Agent

Post `/approve` as an issue comment to trigger the Copilot coding agent workflow
(`issue-approve.yml`). This adds `approved` + `copilot-agent` labels and assigns
the issue to Copilot. The `@copilot` mention does **not** trigger the agent.

## Worktrees

When creating worktrees, use naming pattern: `../<repo>-wt-<issue-or-pr>` (e.g., `../basecoat-wt-1334`).

Worktree cleanup safety playbook:

1. Verify branch-to-path mapping with `git worktree list` before removal.
2. Never delete worktrees by assumed paths.
3. Use `git worktree prune` only after mapping is confirmed and stale entries are identified.
