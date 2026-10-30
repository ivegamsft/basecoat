# Ordered Delivery Admission and Holds Proposal

## Status and prerequisites

Proposal only, related to [source #3671](internal source issue).
No queue, workflow, hold label, rule or setting changes are authorized by this document.
Merge of the proposal does not approve implementation or complete source acceptance.
No new aliases or automatic source approval are supported.

Readiness consumes the identity contract proposed in
[completion readiness proposal #3718](internal source pull request);
that capability remains a runtime prerequisite, not a delivered dependency.
[Hybrid branching](../operations/hybrid-branching-policy-contract.md),
[stack guidance](../guides/stacked-pr-integration.md), and
[governance](../reference/governance-contract.md) remain controlling contracts.

## Current evidence versus proposed behavior

Inspected baseline: `b2cb3c03003dc40f0eb4a67c32dfa69a2e4aae11`.
`pr-auto-merge-executor.yml` uses the canonical `delivery-hold`, checks it at evaluation
and before enabling auto-merge, and rechecks the head. Its concurrency keys vary by
event/PR; they do not establish one global age-ordered admission writer.
It uses an event-generating queue token and head-matched native admission.
The ruleset serializes queue grouping; this is not source-age scheduling.

Source examples of draft staging and recovery admissions are historical evidence of
the scheduling distinction. This proposal does not assert a current queue order,
unauthorized merge, or hosted acceptance. Future ordering is conditional on controlling
all admissions in the declared scope, not just one workflow.

## Non-goals and authority

Do not make complete work draft for scheduling, disable the native queue, invent
dependencies between independent work, infer approval from expiry, or auto-close sources.
Solo-dev XL keeps zero routine PR reviews; XXL qualified approval is unchanged.
Readiness, scheduling, eligibility and admission are four independent states.

The existing ship-it delivery owner maintains scope membership and dependency evidence;
workflow maintainers own one admission writer and reconciliation.
Existing executor and approval/decomposition helpers own eligibility, not the scheduler.
An ordered hold is observable scheduling state, not source approval or a review request.

## Requirements traceability

| Source requirement | Proposed contract / result |
|---|---|
| Ready versus held | Ready PR remains ready while scheduling state excludes admission |
| Durable scope/key/dependencies | Explicit immutable scope record and ordering below |
| Older blocked work | Durable blocker plus explicit owner exception before advancing |
| One admission writer | All automated/manual scope admissions reconciled or no order guarantee |
| Retry, expiry, metadata events | No authority grant; current identity rechecked |
| Concurrent operators | Durable writer proof and actual-effects fixtures required |

## Input/output identity and exact ordering

Proposed scope key: repository immutable ID + protected target ref + explicit delivery
scope ID/version recorded by the existing owner. Scope membership is a durable snapshot
of authorized source items, not every PR ever opened or a transient sprint label search.
Any guarantee is local to that scope; interactions with other scopes require a shared
repository/target admission writer and explicitly declared precedence.

Proposed immutable item key: authoritative primary source `created_at` in UTC,
then primary issue number, then PR number. Missing/ambiguous primary source is blocked;
an approved multi-source finalization uses the oldest included source, with its full
membership recorded. Revisions to membership/primary source require an owner-recorded
reason and a new scope version, not quiet priority rewriting.

Declared validated dependencies take precedence: a prerequisite must be delivered
before its dependent. Choose the smallest item key among dependency-admissible items.
Record why a younger prerequisite precedes an older dependent. Cycles/missing dependencies
block the affected scope. No dependency is inferred from numbering or labels alone.
Stack finalization is one item; layers are not independent main admissions.

Input includes scope/version, ordered inventory and dependency revisions, PR head/base,
readiness/authority evidence, policy revision, hold record and observed queue state.
Output includes immutable decision ID, ordering position, blockers/exception evidence,
admission intent/result and native queue identity, current head, writer and resume cursor.
These are ledger fields, not new labels or approval mechanisms.

## Hold and admission transitions

1. Reconcile ready items without changing draft state. Use existing `delivery-hold`
   as the observable exclusion indicator; proposed durable details carry scope, PR,
   owner, reason, created time, expiry/review time, revision and resume evidence.
   Missing details or unexplained label removal blocks rather than authorizes.
2. Report each older blocked/held item, exact blocker, age and next owner action.
   Default is stop advancement past it. A qualified scoped owner may record an explicit
   scheduling exception naming skipped item, reason, eligible successor and scope version.
   This is not implementation/source approval and cannot bypass delivery-policy blockers.
3. For the chosen item, re-fetch head/base, readiness, holds, dependencies, scoped
   approval, decomposition and eligibility immediately before admission.
   Metadata repair or expiry merely requests reconciliation; it does not auto-enqueue.
4. Only the single admission writer submits the head-matched native request and records
   observed result. Do not promise native merge order beyond admitted order/existing queue
   behavior; removals, rebuilds and platform policy can change later queue outcomes.
5. Hold expiry marks review overdue, never clears itself into authority.
   Guarded cleanup requires authorized resume evidence and current revision comparison.
   Resume changes scheduling state only; all delivery gates must pass again.
6. Re-fetch after mutation. A head change, missed event or untracked admission invalidates
   intent and pauses reconciliation; do not destructively dequeue unrelated live groups.

## Concurrency, idempotency, bounded recovery

One repository/target admission writer must own all event paths, including manual/API
actors and metadata-triggered executor paths. If any writer remains uncontrolled,
report best-effort ordering and the limitation; exact queue order cannot be promised.
An eligibility barrier alone does not prove oldest-first writer exclusivity.

Proposed operation key: repository/target + scope/version + item + head/base +
decision revision. Persist intent before requesting admission and result after observing
native state. Duplicate events re-fetch and return already admitted or blocked.
On timeout/crash, inspect actual queue/auto-merge state before retrying; an ambiguous
request is not evidence of failure or permission to repeat.

Existing Actions concurrency is insufficient as a durable lock across all actors.
Durable surface, writer fencing, revision-conflict handling and token boundaries remain
owner-selected prerequisites; this document invents no CAS or distributed-lock guarantee.
Proposed bound: three attempts per unchanged identity, two repeated failures report
remediation, three or 24 hours pause/escalate under hybrid policy.
Resume requires explicit blocker resolution plus current evidence, never elapsed time.

## Actual-behavior fixture plan

Disposable-repository tests must inspect ready/draft state, durable decisions and
native admission effects. Production recovery timelines are not fixture acceptance.

| Fixture | Required result |
|---|---|
| Three ready independent items arriving out of order | Admissions follow recorded age key |
| Older dependent with younger prerequisite | Dependency precedence recorded, no invented edge |
| Older blocked/held item | Visible blocker; no silent bypass; scoped exception auditable |
| Metadata repair on newer item | Reconcile scope; no admission ahead of older eligible work |
| Hold expires or label removed without resume evidence | No new authority or automatic admission |
| Two operators / duplicate event / worker crash | One proven writer or explicit best-effort limitation |
| New push after decision / inaccessible authority | Stale intent blocked; bounded pause |
| Already queued outside writer | Detect deviation, pause; do not claim exact order |
| Ready held PR / XXL missing qualified approval | Draft unchanged; policy blocker preserved |

## Alternatives, rollout, and missing decisions

Reject draft-as-hold and admission-order-as-age-order.
Manual serialized scheduling remains the fallback; a repository/target-wide writer
offers a stronger guarantee only after every entry path is controlled.
Storage and how existing manual actors delegate admissions require owner decisions.
Direct admission policy enforcement is separately tracked by #3672; its design must
not wait for queue admission to establish eligibility.

Missing prerequisites: approved finalized contract/required PRD, readiness identity,
durable scope/hold surface, all-writer inventory and enforceable ownership, conflict
semantics, API-effects fixtures, and separately authorized runtime implementation.
Stage 0 keeps runtime default off. Stage 1 computes shadow order without writes;
stage 2 tests disposable concurrent actors. Separately approved pilot scopes may follow
only after writer control is demonstrated; preserve current holds/native checks.
Stop on untracked admission, silent age bypass, destructive reconciliation or authority drift.
Rollback disables new scheduling writes, retains ledger/hold evidence and returns to
existing manual serialized recovery. Expired holds stay held pending scoped resolution.

## Implementation status

Stage 1 shadow logic in `.github/base-coat/scripts/ordered-delivery-holds.cjs` (tests: `tests/ordered-delivery-holds-tests.cjs`) computes age keys, dependency precedence, blocked-item reports,
scoped exceptions, hold expiry/resume and recovery without writes; order is best-effort unless the writer controls every entry path.
