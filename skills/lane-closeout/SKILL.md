---
name: lane-closeout
description: "Safely finishes work in a branch or worktree lane. USE FOR: capture dirty WIP, sync and publish a lane, create or update its PR, classify MERGED/HANDED_OFF/ABANDONED/PARKED, return to synced main, and prune only proven terminal lanes. DO NOT USE FOR: force-pushing conflicts, deleting active worktrees, bypassing checks, or cleaning unrelated branches."
compatibility: [copilot-coding-agent, github-copilot-cli, vscode-chat]
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
  unload_on_exit:
    - scratch.lane_status
  handoff_schema:
    - lane
    - terminal_state
    - evidence
    - next_action
  max_context_budget: 4000
---

# Lane Closeout

Finish one branch plus its optional worktree without losing WIP or assuming that
cleanup is safe.

## Inputs

- Repository, lane branch, and optional worktree path
- Mode: `full` or `safe` (`safe` is capture, push, and report only)
- Merge/abandon authorization and ledger destination

## Contract

1. **Map** — run `git worktree list --porcelain`; verify the exact
   path-to-branch mapping, active owner, status, upstream, PR, and `main`
   worktree. Never infer a path.
2. **Capture** — if dirty, commit reviewed changes to the lane. If that is not
   safe or execution is interrupted, preserve them on a unique `wip/<lane>-<tree>`
   ref and push when no sensitive-path warning exists. Never discard, reset, or
   overwrite WIP.
3. **Sync** — in `full` mode fetch and rebase on `origin/main`. On conflict,
   abort the rebase, preserve and push a WIP ref, then classify `PARKED`.
4. **Publish** — push without force. Create one PR when absent; otherwise update
   the existing PR and evidence.
5. **Classify exactly once**:
   - `MERGED`: already merged, or explicitly authorized with all gates green.
   - `HANDED_OFF`: PR remains open due to review, CI, label, or approval gates.
   - `ABANDONED`: zero net change or verified supersession, with explicit rationale.
   - `PARKED`: conflict, interruption, sensitive-path warning, or failed publish.
6. **Prune** — only for `MERGED` or authorized `ABANDONED`. Delegate branch
   deletion to `@branch-hygiene-sweeper` and worktree removal to
   `git-worktrees`; re-check mapping and cleanliness immediately before removal.
7. **Return and record** — use the discovered `main` worktree, pull with
   `--ff-only`, confirm clean, and write an idempotent ledger record plus compact
   evidence summary.

Safe mode never rebases, merges, closes PRs, deletes branches, removes
worktrees, or switches another checkout. See `references/workflow.md`.
