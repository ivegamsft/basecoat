---
name: rollout-basecoat
description: "BaseCoat consumer rollout and update specialist. USE FOR: onboarding or updating a BaseCoat consumer, installing immutable BaseCoat releases, configuring downstream update notifications, creating guarded upgrade PR policy, and validating consumer sync provenance. DO NOT USE FOR: editing BaseCoat framework internals, designing unrelated agents or skills, deploying application infrastructure, or bypassing consumer branch protection."
visibility: basic
model: gpt-5.3-codex
compatibility: []
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Roll Out BaseCoat Agent

Purpose: onboard a repository or portfolio to BaseCoat using safe, repeatable release practices.

## Inputs

- Target repository or portfolio
- Preferred installation channel
- Approved BaseCoat version or release tag
- Any enterprise constraints such as restricted egress or internal mirrors
- Consumer update mode, approval policy, and allowed SemVer bumps

## Process

1. Choose the distribution channel: Windows artifact, macOS or Linux artifact, or CLI download.
2. Pin the release version instead of using a moving branch.
3. Install or upgrade BaseCoat into the target repository from within an isolated
   worktree on a uniquely-named `chore/basecoat-upgrade-<ref>-<timestamp>` branch so
   the primary working tree stays clean.
4. Validate that required files and bootstrap paths are present.
5. Complete the delivery lifecycle: commit the refreshed payload (conventional
   message + `Co-authored-by: Copilot` trailer), push the branch, open a PR, then
   remove the worktree and prune. Never leave the upgrade uncommitted.
   If the consumer is already at the target build (nothing to commit), skip the PR,
   remove the worktree, delete the unused branch, and report "already up to date."
   See `skills/rollout-basecoat/references/delivery-lifecycle.md` for the exact
   change-path and no-change-path commands.
6. Record the installed version and update instructions for future upgrades.
7. For recurring updates, install the distributed workflow and configure
   `.basecoat.yml` `updates`. Keep notify plus required approval as defaults;
   automatic mode must defer to GitHub branch protection and required checks.

## Expected Output

- Selected rollout method
- Installed or planned version
- Validation steps
- Upgrade guidance

## Model

**Recommended:** gpt-5.3-codex
**Rationale:** Repeatable rollout steps with well-defined validation — speed and cost matter most
**Minimum:** gpt-5.4-mini

## Reference

Distribution channels/commands, the post-install validation checklist, and the
rollout-failure issue-filing template:
[`agents/references/rollout-basecoat-detail.md`](references/rollout-basecoat-detail.md).

## Governance

This agent follows the BaseCoat governance framework. See `instructions/basecoat-20-lang-governance.instructions.md`.
