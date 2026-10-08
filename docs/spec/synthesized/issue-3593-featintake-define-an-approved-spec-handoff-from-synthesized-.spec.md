---
issue: 3593
title: "feat(intake): define an approved-spec handoff from synthesized draft to implementation"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Spec: feat(intake): define an approved-spec handoff from synthesized draft to implementation

## Problem Statement

Fallback synthesis ends at a draft PR and lacks an explicit validated transition into the approved implementation path.

## Prerequisites and Design

Require merged #3591 shared authority validation and the #3592 serialized
assignment adapter before enabling assignment writes. A missing prerequisite
is blocked, not a second implementation of approval or assignment.
The synthesis producer continues creating draft spec PRs only.

The finalized spec PR must merge before handoff. Add a distinct, exact
source-issue command in the shared approval parser:

```text
/approve-spec <spec-pr-number> <40-character-approved-head-sha>
```

The entire trimmed comment must match this grammar, with positive decimal PR
number and ASCII hexadecimal SHA. Quoted, incidental, multiline or bot commands
do not qualify. Preserve existing exact `/approve` semantics; neither command
is treated as a substring of the other. `/spec-2-prod` is a delivery request,
not a new approval authority.

This syntax is proposed for implementation, not supported by this documentation
PR. Do not post the directive as a test or manufacture source evidence.

## Identity and Source Contract

Resolve the directive from its original comment ID on the open source issue.
Re-read the actor and current qualified permission with #3591 helpers.
Require same-repository spec PR, default-branch target, merged state,
unambiguous source issue linkage, and the approved SHA equal to the PR's final
head. Reject a merge after an unapproved head change.

Resolve the merged commit and declared PRD/spec paths in that immutable tree.
Require both to exist, be non-placeholder, name the same source issue and carry
reviewed/implementation-ready status. Record their Git blob identities and
canonical repository URLs. Verify those blobs remain identical in current
trusted main immediately before assignment; changed spec content requires a
fresh qualified directive, not an updated bot receipt.

The issue must point to exactly that immutable validated Spec URL through
the #3591 intake contract. Updating a source Spec field is a separately authorized
intake action, never an implicit bot rewrite by this handoff.
Do not infer source linkage or spec paths from arbitrary executable text.

### Source hold and deferred-intent contract

Read the current source issue from GitHub at every evaluation boundary. Its
body must contain exactly one nonblank line of the form
`Delivery intent: <value>`; the key is exact and the trimmed value is compared
case-insensitively. Only `implementation` is executable. Missing, duplicate,
malformed, `logging-only`, `deferred`, or any unrecognized value fails closed.
The issue must also be open, have no `blocked`, `deferred`, `delivery-hold`,
`needs-info`, `duplicate`, `invalid`, or `wontfix` label (case-insensitive),
and have no unresolved dependency under #3591. The `deferred` and
`delivery-hold` labels must be provisioned and verified before production
rollout; until then, assignment writes stay disabled. Inaccessible labels,
body, state, permissions, or dependency evidence are unknown and therefore
blocked. Do not infer an override from free text, a bot receipt, an approval
label, or a previous assignment status.

A hold is cleared only after all blocking labels and unresolved dependencies
are gone, the source issue's authoritative `Delivery intent` field is changed
to `implementation`, and a qualified human posts a new exact
`/approve-spec <spec-pr-number> <approved-head-sha>` comment after those
changes. Re-read the issue event/comment timestamps and original directive
identity; a directive created before the last hold-clearance edit is stale and
cannot be reused. Removing a label or changing the field alone does not
authorize handoff. If edit chronology cannot be established, remain blocked.

## Durable State and Handoff

Use a stable identity over repository ID, source issue, original directive ID,
spec PR, approved head, merged commit, and PRD/spec blob identities.
Persist the original authority URL and exact identity in an auditable status
record. A bot receipt is comparison metadata, not authorization; re-fetch the
same original directive and permission at every execution boundary.

States are `spec-draft`, `awaiting-directive`, `handoff-pending`, `blocked`,
`authorization-invalid`, and `assigned`. `assigned` requires actual coding-agent
assignee read-back; session/PR execution may remain explicitly unobserved.
Never report implementation started based only on approved/copilot-agent labels.

Both initial handoff and reconciliation invoke the #3592 shared worker with its
same per-issue concurrency group. Only that worker owns attempt persistence and
assignment calls. Reuse its epoch/retry budget; schedule ticks, reruns and
status comments never create a fresh epoch. After a lost dispatch/assignment
response, re-read worker state and actual assignees before another request.
An already observed assignment is no second handoff.

Revoked/deleted/edited directives, changed spec blobs or dependencies fail
closed before the next assignment. Do not revoke valid historical authority
merely because an API request failed; retain evidence and owner action.

## Canary and write enablement

The default mode is read-only discovery; no assignment call is made. Live
assignment is enabled first only as a canary through trusted configuration
that binds exactly one source issue, its qualified directive comment ID, the
merged spec PR/head/commit and PRD/spec blob identities. The canary tuple must
pass all current source-hold, authority, dependency, worker-budget and
assignee-readback checks above. Only that exact tuple can invoke the shared
worker contract in #3592; every other issue stays read-only. Do not create an approval,
change intent, or edit source metadata to manufacture the canary.

General assignment remains disabled until GitHub read-back confirms the
expected coding-agent assignee on the canary issue and its recorded source,
spec, directive and worker identities match the allowlisted tuple. Promotion
requires a separate protected configuration change after that verification;
the canary workflow cannot promote itself. If there is no genuinely
authorized issue/spec fixture for the canary, retain read-only mode and report
live acceptance as blocked.

## Implementation and Verification

Wire source-issue handling and trusted spec-merge/reconciliation discovery into
one shared handoff resolver. Merge discovery records readiness only; it cannot
approve or assign without the qualified exact directive. Synchronize downstream
workflow/helper copies, existing runner registration and bound workflow digests.
No new credential expansion or routine human PR-review gate is introduced.

Execute actual workflow-script fixtures covering successful merged binding,
changed PR head, changed/deleted blobs, multiple source issues, unmerged/draft
specs, malformed URLs, bot/quoted commands, held/deferred work, unresolved
dependencies, revoked/deleted directives, concurrent notifications, lost
responses, exhausted assignment budget and repeated synthesis branch reuse.
Assert assignment call counts, epoch stability and assignee read-back.

Test missing, duplicate and malformed `Delivery intent`; every active hold
label; unresolved dependencies; labels removed before/after the directive;
unqualified edits; and a qualified fresh directive after clearance. Assert
that only the post-clearance directive can proceed and every uncertain
timeline remains blocked.

Exercise the configured one-issue canary end to end, including its exact
allowlist tuple, assignment call count, worker retry budget and persisted
assignee read-back. Prove a second issue, changed directive/spec identity, or
canary failure cannot enable general writes. Do not create approval to satisfy
a test. If no controlled authorized fixture exists, report that live
acceptance remains blocked and keep writes disabled.

## Failure, Rollout and Observability

Inaccessible PR/spec/permission evidence is blocked with a concrete owner
action, never treated as absent approval or success. Retry only the existing
bounded transient-read policy; assignment retries follow #3592 exactly.
Emit source/spec identity, state, budget, sanitized failure category and genuine
evidence URLs. Never expose tokens or raw private session data.

Rollback disables the new handoff entry point while preserving original
directives/state; never bulk-unassign agents or turn old receipts into approval.
Risks include changed authority, stale spec identity, conflicting producers and
mistaking assignment for execution; verify each boundary independently.

## Acceptance Criteria

- [ ] Synthesis and merged spec readiness remain distinct from approval.
- [ ] Immutable spec binding and current qualified authority gate one handoff.
- [ ] Both producers share #3592 serialization and bounded retry state.
- [ ] Held/deferred/invalid/replayed evidence cannot trigger execution or duplicate work; clearance requires a fresh qualified directive.
- [ ] One trusted, exact-identity canary is the only write path before general enablement.
- [ ] General enablement requires verified canary assignee read-back and a separate protected configuration change.
- [ ] This specification PR does not implement or close #3593.

## References

- PRD: `docs/prd/synthesized/issue-3593-featintake-define-an-approved-spec-handoff-from-synthesized-.prd.md`
- Refs #3593
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3593>
