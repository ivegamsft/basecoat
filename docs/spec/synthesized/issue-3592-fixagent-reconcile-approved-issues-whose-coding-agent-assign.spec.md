---
issue: 3592
title: "fix(agent): reconcile approved issues whose coding-agent assignment failed"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["bug", "priority:high", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Spec: fix(agent): reconcile approved issues whose coding-agent assignment failed

## Problem Statement

Approval labels can indicate implementation readiness even when no coding agent was successfully assigned.

Issue approval and coding-agent assignment are separate facts. Keep accepted
authorization, but require observed assignment before claiming recovery.

## Design and Interfaces

Reuse `issue-approve.yml` capability discovery and assignment payload, its
distributed counterpart, and the existing watchdog/reconciliation surface.
Extract shared assignment-state transitions rather than duplicating approval
logic. Implementation is blocked until #3591's reviewed approval contract and
implementation are merged. Both original and recovery paths must use
`docs/spec/issue-3591-approval-contract.spec.md` and its shared authority helper;
do not substitute approval labels or an older forwarding directive. If that
dependency is absent or unavailable, report blocked and make no assignment.
Run trusted base-branch code only; issue text is data, never executable input.

Record an upserted repository-owned status comment with marker
`<!-- basecoat-agent-assignment:v1 -->`. Include issue number, original approval
reference, state, attempts consumed, maximum attempts, next retry time, last
failure category, owner action, and verified assignee/execution links.
Comments and labels are observations, not authorization.

States are `pending`, `retryable`, `blocked`, `assigned`, and
`authorization-invalid`. `assigned` means the coding-agent assignee was read
back from GitHub, not that a coding session necessarily started. Distinguish
execution as `observed` with a real PR/session URL or `unobserved` explicitly.
Do not describe `pending`, `retryable`, or `blocked` work as started.

An assignment epoch is scoped to issue, qualified original approval identity,
and validated spec reference. Body edits, relabeling, and schedule ticks do not
reset the attempt budget. A materially changed authorization requires fresh
validation and an explicit new epoch; never mint one from a bot status comment.

## Reconciliation and Idempotency

Select a bounded paginated set of open approved issues with an unresolved
assignment state. Use existing repository pacing and cap each sweep.

Both producers must invoke one trusted assignment worker with job-level GitHub
Actions concurrency group `basecoat-agent-assignment-<repository-id>-<issue-number>`
and `cancel-in-progress: false`. The worker owns every attempt-counter read,
status write, and assignment request; neither producer may bypass it. Use the
same group across the original approval and watchdog workflows, not their
independent workflow-level groups. A marker comment alone is not a lock.

Queued notifications may be coalesced by Actions' single pending slot. The
watchdog must discover unresolved approved issues from live evidence rather
than depend on every notification being executed. GitHub releases the active
concurrency slot on terminal completion or cancellation; a cancelled worker's
persisted consumed attempt remains consumed. Recovery must read back assignees
and current authorization before proceeding, never reset an epoch to recover a
stale run. If the worker is still active, defer rather than stealing its slot.

Inside that serialized worker, before every attempt:

1. Re-read the open issue, dependencies, spec evidence, and original approval.
   Revalidate the approving actor's current qualified permission. Draft or
   closed work, revoked authority, and unresolved dependencies cannot assign.
2. Read current assignees. If the coding agent is already assigned, verify that
   state and stop without another assignment call.
3. Check capability discovery and configured agent availability. Disabled or
   unsupported capability becomes `blocked` with a concrete owner action.
4. Persist the consumed attempt before requesting assignment. If the response
   is lost, re-read assignees before retrying; never assume request success.
5. Read assignees after assignment. Only a persisted coding-agent assignee
   permits `assigned`; otherwise retain a non-started state.

Use a configurable finite budget, default three assignment requests per epoch.
Persist attempt consumption before each request; all HTTP retries that submit
an assignment request consume that budget, with no hidden inner retry loop.
Use exponential retry delays of 30 seconds, multiplied by 1.5 after each retry,
capped at 90 seconds. With the default budget, request two follows a 30-second
delay and request three a 45-second delay. Honor a longer `Retry-After` by
persisting the later next-retry timestamp and deferring to a future sweep,
not by retrying at the cap. Read-only discovery/read-back calls may use their
existing bounded API retry helper without consuming assignment attempts;
failure of those reads prevents another assignment request.

Retry only throttling, transient server/network errors,
or explicitly documented eventual-consistency failures. Auth/permission,
invalid payload, disabled capability, and unsupported operations are permanent
blocks. Exhaustion becomes `blocked`, not another automatic epoch.

Do not revoke accepted approval merely because assignment failed. When current
authority is invalid, report `authorization-invalid` and make no assignment;
restoring access does not erase audit history or implicitly authorize new scope.
Avoid overwriting other assignees. After conflicting human changes, stop and
report the observed conflict rather than repeatedly repairing live state.

## Failure and Trust Contract

| Failure | Required result |
| --- | --- |
| Preflight or dependency lookup unavailable | Explicit retryable/blocked status, no started claim |
| Capability disabled or absent | Permanent blocked state with configuration owner/action |
| API accepts request but assignee absent | Non-started state, read-back evidence, bounded consistency retry |
| Response lost after successful assignment | Verify existing assignee; no duplicate request |
| Authority revoked or spec invalid | Authorization-invalid, no write to assignment |
| Attempt budget exhausted | Blocked with evidence and next owner action |
| Status persistence fails | Surface error and stop; no success-shaped fallback |

Use least-privilege existing issue/assignment permissions, no credential
expansion. Never expose tokens, raw sensitive API responses, or private session
content in status comments. Validate repository, issue, actor, spec, and URLs.
Bot-authored marker content cannot replace live evidence or original authority.

## Implementation and Testing

Implement a shared state adapter with mocked GitHub capability/assignment
calls. Wire original approval and recovery into that adapter, keep distributed
workflow/helper copies consistent, and update bound workflow digests.
The watchdog must use assignment evidence rather than issue `updated_at` alone
to report started/stalled work; unrelated comments must not restart a timer.

Tests inject every failure above, repeated sweeps, concurrent notifications
from both workflows, pending-notification coalescing, worker cancellation
after attempt persistence, absent approval-contract dependency,
lost responses, exhausted budgets, changed dependencies/spec/permissions,
preserved human assignees, and a verified success. Assert API call counts and
status transitions, exact retry timestamps, no hidden assignment retries,
no duplicate assignment, and no accidental approval reset.

## Rollout, Observability, and Rollback

Start with read-only recovery reporting, then enable writes only after fixture
and controlled approved-issue tests pass. A live recovery test must use an
explicitly authorized scoped issue and observe the actual assignee; an API
dispatch or label alone is not E2E success.

Record state counts, attempt budget consumption, failure categories,
verification timestamp, and links to genuine execution evidence when present.
Rollback disables reconciliation and restores the previous workflow while
retaining authorization/audit comments. Do not bulk-unassign coding agents.
Risks include incomplete capability data, late assignment visibility, concurrent
human edits, and missing execution URLs; preserve explicit unknowns.

## Acceptance Criteria

- [ ] Both assignment paths follow the shared state and current-authority contract.
- [ ] Failure/replay fixtures verify finite retries and observed assignment.
- [ ] Original accepted authorization remains auditable and is not synthesized.
- [ ] Controlled live recovery proves an assignee, not only an assignment request.
- [ ] Implementation PR links this spec and records exact commands and outcomes.
- [ ] #3592 remains open until implementation and recovery verification pass.

## References

- PRD: `docs/prd/synthesized/issue-3592-fixagent-reconcile-approved-issues-whose-coding-agent-assign.prd.md`
- Refs #3592
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3592>
