---
name: rollout-basecoat
compatibility: [github-copilot-cli]
description: "Use when refreshing a consumer repository or configuring BaseCoat consumer updates. USE FOR: refresh basecoat, update basecoat, configure downstream update notifications, enable guarded BaseCoat upgrade PRs, run sync.ps1 or sync.sh with .basecoat.yml defaults, verify installed versions, recover rollout failures. DO NOT USE FOR: editing BaseCoat framework internals, designing new agents or skills, unrelated deployments."
category: operations

visibility: public
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Rollout BaseCoat Skill

Refresh a consumer repository to the latest or pinned BaseCoat build.

## Shortcut Phrases

- refresh basecoat
- update basecoat
- upgrade basecoat in this repo
- open guarded BaseCoat upgrade PRs

## Workflow

Use an **isolated worktree** and complete delivery; do not leave sync changes
uncommitted.

1. Read `.basecoat.yml` for `source`/`ref`; create a fresh worktree and branch
   from the resolved default branch.
2. Before sync, capture factory-owned active workflow targets with
   `.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1
   -CaptureWorkflowSelection`. Stop on partial ship-it or missing/invalid
   ownership evidence.
3. Resolve `sync.script` or the canonical sync entrypoint and run it in the
   worktree. Verify version and provenance; sync rejects mismatched semver pins.
4. Refresh only captured targets with the staged targeted installer, then
   validate the staged payload and consumer workflows. Never enable defaults.
   Staged-only consumers remain opt-in; report the activation command and
   permission/trigger effects. Do not deliver after installer or validation
   failure.
5. Commit, push, and open a PR; if there are no changes, report "already up to
   date." Compare releases with
   `gh release list --repo SOURCE-ORG/basecoat --limit 1`.
6. Report changes, PR URL, readiness, and follow-up steps.

For recurring consumer-owned updates, configure `.basecoat.yml` `updates` policy
and install the distributed check workflow. Defaults remain notify plus required
approval. Automatic mode may request GitHub auto-merge, but never bypasses
required checks or branch protection. Major releases always require approval.

See [`references/delivery-lifecycle.md`](references/delivery-lifecycle.md) for the
exact worktree, commit, push, PR, cleanup, and fallback commands and safety rules.
