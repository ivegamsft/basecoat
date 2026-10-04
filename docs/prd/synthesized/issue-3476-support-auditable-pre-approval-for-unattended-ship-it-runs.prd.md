---
issue: 3476
title: "Support auditable pre-approval for unattended ship-it runs"
status: draft
author: ibuyspy
created: 2026-10-04
labels: ["enhancement", "priority:high", "sprint:2026-W40"]
---

# PRD: Support auditable pre-approval for unattended ship-it runs

## Problem and Outcome

An unattended ship-it run should consume an already recorded human decision,
not manufacture its own approval or require a human to repeat approval at kickoff.
The comment-command authorization and the solo-dev `approved-issue` requirement
are distinct gates; neither authorizes PR approval or production cutover.

## Scope

- Reuse the existing `approved` issue label plus an exact qualified human
  `/approve` comment as the sole pre-approval authority.
- Add explicit source-issue/comment references to unattended dispatch, preserving
  the execution principal separately from the original human approver.
- Validate source scope, immutable spec reference, timestamp, current permission,
  and live revocation at dispatch and delivery boundaries.
- Preserve repository authorization, required checks, XXL/risk human reviews,
  and production environment approvals.
- Exclude implementation from this PR, new approval registries/tokens, self-
  approval, automatic approval-label copying, and approval bypasses.

## Success Criteria

- A same-repository authorized run can start without a new human command when
  exact, in-scope, pre-existing qualified evidence remains valid.
- Bot/agent-created approval, label-only approval, non-exact comments, ambiguous
  scope, and approval first recorded at/after run start cannot authorize execution.
- Editing/deleting evidence, removing the label, changing approved scope, or
  losing permission blocks the next boundary and prevents automatic merging.
- Issue approval never counts as a qualified PR review or production approval.
- Positive, negative, time-equality, revocation, and XXL threshold tests in the
  spec are implemented before rollout.

## Delivery and Risk

Ship behind an explicit pre-approval mode, starting with dry-run fixtures.
Rollback disables that mode while preserving existing interactive dispatch.
The critical risk is laundering approval through the executing agent; live
GitHub evidence, strict provenance, and independent gate evaluation prevent it.

## References

- Spec: [implementation contract](../../spec/synthesized/issue-3476-support-auditable-pre-approval-for-unattended-ship-it-runs.spec.md)
- Governance: `docs/reference/governance-contract.md`
- Refs #3476
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3476>
