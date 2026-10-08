---
issue: 3593
title: "feat(intake): define an approved-spec handoff from synthesized draft to implementation"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: feat(intake): define an approved-spec handoff from synthesized draft to implementation

## Problem Statement

Fallback synthesis ends at a draft PR and lacks an explicit validated transition into the approved implementation path.

Generated documentation is a proposal, not authorization. The next transition
must bind a qualified directive to finalized spec content and retain that
identity through a single recoverable implementation handoff.

## Scope

Require the spec PR to merge first, then accept a source-issue directive naming
that PR and its approved head. Bind immutable merged spec content, source issue,
repository, actor and directive identity. Reuse #3591 current-authority
validation and #3592 assignment verification; do not auto-approve synthesis.
Provide explicit pending, blocked and observed-assignment evidence.

The source issue body must contain exactly one nonblank line of the form
`Delivery intent: <value>`; the key is exact and the trimmed value is compared
case-insensitively. Only `implementation` is executable; missing, duplicate,
or malformed values fail closed. Current
`blocked`, `deferred`, `delivery-hold`, `needs-info`, `duplicate`, `invalid`,
or `wontfix` labels, a closed issue, or unresolved dependencies also prevent
handoff. Clearing a hold requires removing the blocking state, setting
`Delivery intent: implementation` through the normal qualified issue-edit
path, and posting a new exact `/approve-spec` directive afterward. A directive
that predates the clearance is stale and cannot be reused. Free-text mentions
of approval, resume, or delivery do not clear a hold.
The `deferred` and `delivery-hold` labels must be provisioned before production
rollout; until their availability is verified, assignment writes remain disabled.

Do not automatically mark generated drafts ready, merge specs, create approval
comments, infer authority from labels, or change routine XS-XL review policy.
Existing unbound `/approve` remains supported for its existing route; it is not
retroactively made authorization for this new finalized-spec handoff.

Assignment rollout starts disabled. A separately enabled canary mode is bound
by trusted configuration to exactly one source issue and its exact qualified
directive/spec identity; only that tuple may reach the existing serialized
assignment worker. General handoff remains disabled until the canary's actual
assignee is read back and verified. Promotion to general enablement is a
separate protected configuration change, never an automatic result of the
canary. If no genuinely authorized canary fixture exists, remain read-only.

## Success Criteria

- [ ] A qualified exact directive for merged immutable spec content produces one handoff.
- [ ] Draft, edited, inaccessible, deferred and unapproved work cannot execute.
- [ ] Source hold state and the fresh qualified action that clears it are deterministic.
- [ ] Current authority, spec identity and dependencies are revalidated before mutation.
- [ ] Replays and lost responses cannot duplicate assignment or reset its budget.
- [ ] Observed assignment, not a dispatch or label, proves implementation handoff.
- [ ] A separately configured single-issue canary is read back before general writes can be enabled.
- [ ] #3593 stays open until implementation and controlled verification pass.

## References

- Refs #3593
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3593>
