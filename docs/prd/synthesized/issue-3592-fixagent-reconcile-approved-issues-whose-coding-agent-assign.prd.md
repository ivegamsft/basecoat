---
issue: 3592
title: "fix(agent): reconcile approved issues whose coding-agent assignment failed"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["bug", "priority:high", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: fix(agent): reconcile approved issues whose coding-agent assignment failed

## Problem Statement

Approval labels can indicate implementation readiness even when no coding agent was successfully assigned.

`issue-approve.yml` accepts authorization before assignment preflight. Retaining
that valid authorization is correct, but labels alone cannot prove execution.
Assignment API rejection, disabled capability, and a nonpersisted assignee must
be visible independently of the approval decision.

## Why This Matters

Operators must distinguish authorized work from active delivery and know
whether to retry a transient assignment failure or resolve a capability block.
Recovery cannot silently invent approval, repeatedly assign the same issue,
or report an agent as started based only on an API request.

## Scope

Extend the existing issue-approval assignment path and watchdog with a shared
assignment-state contract and bounded reconciliation. Reuse current authority,
spec, dependency, and capability validation; #3591 owns approval validation.
Preserve accepted authorization without treating it as proof of an assignee.

Do not alter stage, priority, issue scope, merge checks, or release authority.
No additional human review gates for solo-dev XS through XL are introduced.
This PR defines the contract only; #3592 remains open until implementation and
verified recovery are delivered.

## Success Criteria

- [ ] Preflight failure, disabled capability, assignment rejection, and a missing
      persisted assignee produce explicit non-started states and owner actions.
- [ ] Transient retries are finite, idempotent, and validate current authority
      and dependencies before every attempt.
- [ ] Permanent unavailability does not retry indefinitely or revoke a valid
      approval as a side effect.
- [ ] Success requires observed coding-agent assignment; execution evidence is
      linked when available and is never fabricated from a label.
- [ ] Fixtures and a controlled approved-issue recovery exercise prove the
      contract while leaving unrelated issues untouched.

## References

- Refs #3592
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3592>
