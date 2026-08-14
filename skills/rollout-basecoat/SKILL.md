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

Refresh a consumer repository to the latest BaseCoat build or a pinned release.

## Shortcut Phrases

- refresh basecoat
- update basecoat
- sync basecoat to latest
- upgrade basecoat in this repo
- notify me when BaseCoat updates are available
- open guarded BaseCoat upgrade PRs

## Workflow

Run the upgrade inside an **isolated worktree** and always finish the delivery
lifecycle. Never leave the sync uncommitted — an upgrade that stops at "here is
what changed" is an incomplete run.

1. Read `.basecoat.yml` (if present) for `source` and `ref`.
2. Create an isolated worktree on a fresh, uniquely-named
   `chore/basecoat-upgrade-<ref>-<timestamp>` branch from the consumer's default
   branch (resolve it — it is not always `main`) so the primary tree stays
   untouched and re-runs for a moving ref never collide.
3. Discover the sync entrypoint (`sync.script` from `.basecoat.yml`, else root
   `sync.ps1`/`sync.sh`, else search — see reference) and run it **inside the
   worktree**.
4. Verify `.github/base-coat/version.json`. When `ref` is a semver tag, sync
   enforces provenance and fails on mismatch; known-bad tags auto-remap to the
   first corrected release with a warning to update the pin.
5. Compare with the latest release:
   `gh release list --repo SOURCE-ORG/basecoat --limit 1`.
6. Commit, push, open a PR, then remove the worktree and prune. If the sync
   produced no changes, skip the PR and report "already up to date."
7. Report what changed, the PR URL, and any follow-up steps.

For recurring consumer-owned updates, configure `.basecoat.yml` `updates` policy
and install the distributed check workflow. Defaults remain notify plus required
approval. Automatic mode may request GitHub auto-merge, but never bypasses
required checks or branch protection. Major releases always require approval.

See [`references/delivery-lifecycle.md`](references/delivery-lifecycle.md) for the
exact worktree, commit, push, PR, cleanup, and fallback commands and safety rules.
