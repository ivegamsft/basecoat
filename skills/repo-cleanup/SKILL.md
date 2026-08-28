---
name: repo-cleanup
description: "Bulk repo-wide hygiene sweep after a wave of PRs merge. USE FOR: one combined request to sync main while cleaning worktrees and deleting proven-safe merged branches after a ship-it wave. DO NOT USE FOR: sync-only, branch-only, or worktree-only requests; single-lane closeout with WIP; deleting open-PR branches; force-pushing; or resolving conflicts."
compatibility: [github-copilot-cli]
visibility: public
category: workflow
metadata:
  category: workflow
  maturity: beta
  audience:
    - developer
allowed-tools: [git, gh, powershell, bash]
context_policy:
  load_scope: minimal
  retention: none
  handoff_schema:
    - branches_deleted
    - worktrees_pruned
    - escalations
  max_context_budget: 4000
---

# Repo Cleanup

Synchronize `main`, inspect worktrees, and remove only approved stale
branches/worktrees. This skill is destructive: use a
dry-run report and approval gate before any removal.

## Workflow

1. Discover worktree mappings and verify the selected `main` worktree is clean.
2. Fetch and fast-forward `main`; enumerate local and remote branches.
3. Resolve all bounded PR records for each candidate and compare exact tip OIDs.
4. Dry-run report and approval gate: report candidates, then stop for approval.
5. Recheck PR state, worktree mappings, cleanliness, and exact refs immediately
   before each approved removal or deletion. Immediately before deleting each branch,
   re-run the bounded PR query; re-check PR state and worktree mapping immediately before
   every deletion and immediately before each `git worktree remove`.
6. Remove approved worktrees, delete local branches with `git branch -d`, and
   delete remote branches with an exact `--force-with-lease`.
7. Report scanned branches, removals, safe deletions, and escalations.

## Guardrails

- Never destructively touch `main`, `wip/`, `preserved/`, `backup/`, release, or freeze-protected branches.
- Keep open-PR, dirty, recent/no-PR, ambiguous, moved-tip, and active-worktree branches.
- Never force-delete a local branch (`-D`) — never `-D` — force-update `main`, or run bare `git worktree prune`.
- Never skip the approval gate or the immediate pre-delete rechecks.
- Never skip the dry-run report and approval gate.
- Use `gh pr list --head <branch> --state all --limit 50`; treat a result count equal to the limit as truncated.
  Remote deletion requires an exact-ref compare-and-swap using
  `refs/heads/<branch>` and `--force-with-lease=refs/heads/<branch>:<expected-object-id>`.
- This skill does not delegate any part of its workflow to `@branch-hygiene-sweeper`.

Full classification rules, race checks, and command contracts are in
[`contract.md`](contract.md).

## Related Assets

- `skills/git-worktrees/SKILL.md` — worktree mechanics.
- `skills/lane-closeout/SKILL.md` — WIP-safe single-lane closeout.
