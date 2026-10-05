---
issue: 3499
title: "Repository-scoped native queue activation contract"
status: draft
author: ibuyspy
created: 2026-10-05
labels: ["governance", "priority:high"]
---

# Specification: Repository-scoped native queue activation

## Declarative ruleset

- Name: `main-merge-queue-enforcement`.
- Owner/source: `IBuySpy-Shared/basecoat`; scope only `refs/heads/main`.
- Rules: strict required status checks plus `merge_queue`; no `pull_request`
  rule and no bypass actors.
- Checks: the six contexts from `.github/governance/policy-packs.json`
  `solo-dev.main.required_checks`, plus `Agent merge guardrails` from
  `solo-dev.cloud_agent.required_status_checks`.
- Each check is bound to GitHub Actions app ID `15368`, observed from successful
  check runs. The cloud-agent context is the actual job name emitted by
  `.github/workflows/agent-merge.yml`, not a reconstructed workflow/job label.
- Queue parameters: `ALLGREEN`, `SQUASH`, and a maximum of one entry to build
  and merge.

## Apply safety contract

`scripts/deploy-merge-queue.ps1` defaults to local-only contract validation.
`-Preflight` is read-only. `-Apply` requires the active `ibuyspy` account and checks all of the following
before mutation:

1. Readiness PR #3506 is merged and the required workflow contracts are present
   on live `main`.
2. The exact reviewed declarative ruleset from this PR is present on live
   `main`.
3. A successful `Agent merge guardrails` check from GitHub Actions exists on
   the merged readiness head.
4. Main's classic required-status-check protection remains strict, and every
   current branch-protection context is included by the declaration.
5. Squash merge is enabled, and no organization- or enterprise-owned ruleset
   with the target name would be modified.

Apply uses only `/repos/IBuySpy-Shared/basecoat/rulesets` endpoints. It stores a
snapshot outside the repository and verifies the returned ruleset against the
declaration. Rollback requires the snapshot and refuses if the current
repository-owned ruleset identity or post-apply fingerprint changed.

## Preserved controls

- `.github/governance/policy-packs.json` remains unchanged, including the
  deferred solo-dev queue posture.
- No auto-merge executor or branch protection settings are changed.
- Organization and enterprise rulesets, zero approvals through XL, the XXL
  qualified-human boundary, required status checks, signed commits, issue/spec
  authorization, and production gates remain in force.
- Neither this PR nor deployment itself grants permission to bypass required
  checks or directly merge.

## Verification after separately authorized apply

1. Confirm the live repository ruleset is active, repository-owned, and scoped
   only to `main`.
2. Enqueue an already authorized test PR through the native queue.
3. Verify GitHub generated a merge-group revision and each declared required
   check completed successfully on that exact revision.
4. Confirm queue and branch protection state before the parent authorizes
   further queue use.

If any check is missing or fails, stop queue delivery and use the recorded
snapshot for controlled rollback; never weaken inherited rules to recover.
