# Coding-Agent Completion and Readiness Proposal

## Status and source

Proposal only, related to [source #3669](internal source issue).
This is a reviewable implementation contract, not approved runtime authority.
Merging this document neither approves the source/spec nor completes source acceptance.
No new command, label alias, automatic approval, or production setting is introduced.

## Current evidence and governing contracts

Inspected repository baseline: `b2cb3c03003dc40f0eb4a67c32dfa69a2e4aae11`.
[Stack integration](../guides/stacked-pr-integration.md),
[hybrid branching](../operations/hybrid-branching-policy-contract.md), and
[governance](../reference/governance-contract.md) remain controlling references.

- `issue-approve.yml` validates qualified directives with `approval-contract.cjs`;
  its older comment promises a draft, while current assignment instructions request
  a ready implementation PR. Neither wording proves verified task completion.
- `auto-approve-cloud-agent-workflows.yml` approves pending workflow execution
  under policy. Workflow permission is not delivery or readiness authorization.
- `pr-auto-merge-executor.yml` evaluates main-bound eligibility and decomposition;
  `pr-decomposition-evaluator.cjs` and `ship-it/preapproval-evidence.cjs` already own
  decomposition and scoped preapproval evidence. Reuse these, not another parser.
- Source observations of #3666-#3668 and subsequent recovery comments are historical
  incidents, not assertions about those PRs' current heads or live acceptance.

## Non-goals and authority

No assignment, source closure, source approval, queue admission, merge, privileged
workflow change, or inference that a green run delivered its linked issue.
No routine human PR review through XL under solo-dev; XXL retains the explicit
qualified-review boundary. Scope approval and execution approval remain separate.

Future workflow maintainers own the reconciler; existing approval helpers own
qualified source/spec evidence; the delivery executor owns delivery eligibility.
A trusted default-branch worker may fetch metadata but must not execute fork/PR
content with write credentials. Unsupported or inaccessible evidence blocks promotion.

## Requirements traceability

| Source requirement | Proposed contract / observable result |
|---|---|
| Source, spec, task, exact head | Identity below; no cross-task or cross-head receipt reuse |
| Competing local/agent PRs | Enumerate candidates; unresolved competition blocks |
| Template and #3662 decomposition | Existing evaluator on complete current-tree inventory |
| Checks, dependencies, authority | Re-fetch each before any draft-to-ready mutation |
| Incomplete, feature-only, no-op | Explicit dispositions; no automatic parent issue closure |
| Duplicate, push, fork, API failure | Idempotent reconciliation and bounded fixture plan |

## Input and output identity

Input identity is repository immutable ID, source issue number, qualified directive
comment ID and current permission, approved commit-pinned spec path/SHA/digest,
task/assignment ID and generation, PR number, head repository/ref/SHA, base ref/SHA,
policy revision, complete diff inventory, and required-check run/producer identities.
Resolve a mutable spec URL to approved pinned evidence or stop; a URL alone is not approval.
Task identity must come from the trusted assignment/completion producer, not PR text.
Provider support for that binding is an unresolved implementation prerequisite.

Local work uses a trusted local-work ID rather than a fabricated agent assignment.
The existing qualified owner records source/spec/scope authorization and repository,
PR, original/current head and local-work ID in a durable receipt. Independently verify
the directive's original actor/permission and scope, PR creation event/author/repository
from the platform, and observed commit/ref provenance. A creator's statement alone,
duplicate-source text, or a PR-authored task ID is not trusted creation/authorization
evidence. Missing or ambiguous local binding is `unknown`, not proof of no competition;
local completion still needs independently verified scope acceptance and current checks.

The durable output includes that identity, decision generation, evidence references,
canonical exhaustive candidate-set/index digest and revision, coverage horizon/cursors,
observed time, disposition, reason, changed-head invalidation, and retry/resume pointer.
Dispositions: `incomplete`, `blocked`, `competition`, `no-op`, `superseded`,
`complete-feature-only`, `ready`, and `already-ready`. These are record values,
not new labels or public command aliases. Receipts cannot grant authority.

## Reconciliation and promotion

1. Resolve source/spec/task authority with existing helpers and current permission.
   Missing approval, removed/revoked evidence, changed scope or unresolved dependency
   blocks; closing a dependency issue alone does not prove required artifact delivery.
2. Enumerate all open repository PRs and all closed/merged PRs created since the earliest
   included source issue's platform `created_at`, through a recorded lookup timestamp.
   Include trusted agent/local bindings and possible overlapping source/scope matches;
   authored text is a discovery hint only, not authority. Older candidates must be covered
   by a durably retained creation/authorization index extending to repository inception.
   Exhaust pagination to its terminal page or prove equivalent complete indexed coverage
   without retention gaps; retain the horizon, cursor and completeness evidence.
   Proposed scan bound is 100 pages of 100 entries per collection per attempt.
   Hitting a bound, inaccessible page, index gap or ambiguous binding is `unknown` and
   blocks promotion; resume the retained cursor, never silently truncate candidates.
   Do not choose a winner by author, age, or first green result.
   A recorded scoped owner disposition is required when equivalent work competes.
3. Fetch complete paginated diff and current tree. A zero-file completion is `no-op`;
   record whether work already exists, is superseded, or remains unresolved.
   Superseded/no-op records never falsely close the source.
4. Check task completion evidence, scope acceptance, canonical template, decomposition,
   classification, actual dependency delivery, and authorized destination.
   Incomplete work stays draft. Feature-only completion stays draft for this automatic
   handoff; any separate layer-readiness transition needs the stack owner's contract.
5. Check required validations for this exact head and current base/tree, with trusted
   producers; unrelated green runs, workflow approval, and task start are insufficient.
6. Re-fetch authority, candidate set, draft state, base and head immediately before
   promotion. Changed evidence invalidates the decision and restarts reconciliation.
   Persist a trusted completion receipt for the exact source/spec/task/head/base binding
   and complete candidate-set/index digest, revision and coverage evidence.
   Only authorized complete work with an enforceable downstream receipt gate may
   transition draft to ready; already-ready still requires that gate and current receipt.
   Ready does not mean scheduled or merged.

## Concurrency, idempotency, and bounded recovery

Proposed logical operation key: repository ID + full source issue/directive identity +
approved pinned spec path/SHA/digest + trusted agent task/assignment ID or local-work ID +
work generation + PR/head/base identity + policy revision + complete candidate snapshot
digest/revision. Generation alone is not globally unique. Canonically encode the full
tuple; duplicate events converge only for identical authority, work and candidate evidence.
One existing delivery owner must coordinate completion processing and competing
candidate decisions. Workflow concurrency alone is not a transactional lock or CAS.
The current executor has event/PR-scoped groups, not a global completion ledger.

Before implementation, select an existing durable state surface and demonstrate its
single-writer/revision-conflict semantics. The ready API has no expected-head CAS;
`ready_for_review` immediately triggers the executor. A post-mutation read cannot
prevent downstream automation from observing a stale ready transition.
Require a trusted default-branch gate on every downstream eligibility/admission path:
no success until the receipt matches the currently fetched head/base/task/source/spec
binding, valid authority, and a freshly verified complete candidate-set/index snapshot.
Revalidate its digest/revision and coverage immediately before eligibility/admission;
a newly opened competing PR, changed local binding or index gap invalidates the receipt
even with unchanged task/head/base. Missing, stale or untrusted receipts block
even when the PR is non-draft. Final reads and post-mutation invalidation are diagnostic,
not substitutes for this gate or claims of atomic promotion.
The [eligibility barrier proposal #3721 for source #3672](internal source pull request)
must establish enforceable entry control and revocation/race behavior; its publication
does not satisfy that prerequisite. If the gate cannot be enforced, automatic promotion
stays disabled. Completion receipt production must not depend on already being ready,
eligible or queued, avoiding a circular dependency.
Trusted candidate creation/edit/closure/binding events and a completeness-checking poller
must invalidate affected receipts and eligibility before admission when the index changes;
fence older workers so they cannot republish success for the superseded revision.
Event delivery and ordinary API reads are not an atomic snapshot/admission guarantee.
Owners must prove supported writer/index fencing and the pre-admission revocation bound;
if complete current coverage or timely invalidation cannot be guaranteed, automatic
promotion and downstream use of its receipts remain disabled.
New pushes invalidate old completion/check receipts; they cannot inherit readiness
proof even if the platform leaves the PR non-draft.

Proposed bound: three attempts per unchanged identity, with backoff; after two identical
failures report remediation, after three or 24 hours pause and escalate per hybrid
policy. Missing API data fails closed. Resume requires fresh evidence and an explicit
recorded resolution, not a timer or a duplicate event granting approval.

## Actual-behavior fixture plan

Future tests must assert API effects and persisted disposition, not only YAML text.
Use a disposable test repository and trusted stub provider, never mutate production.

| Fixture | Required behavior |
|---|---|
| Qualified completed task, exact-tree green, bounded authorized scope | One ready transition; no enqueue/closure |
| Duplicate completion / already ready | Same identity, zero additional mutations |
| New push/base change during ready mutation before post-read | Stale ready event cannot yield eligibility/admission without exact current receipt |
| Unrelated green run / approved workflow execution | Remain incomplete or blocked |
| Failed check / missing intake / failed decomposition | Draft preserved with actionable failure |
| Fork content requests privileged execution | Metadata-only rejection; no content execution |
| Zero-file task / overlapping local PR | No-op or competition; source stays unresolved |
| Trusted local competitor / authored duplicate-source hint only | Verify local provenance; ambiguous identity blocks, no fabricated agent task |
| Page bound / inaccessible page / older retained competitor | Unknown blocks; resume complete retained lookup, never omit competitor |
| New competitor after receipt / delayed index event / stale worker | Current snapshot mismatch blocks; no admission on old receipt or revision |
| Distinct task/local-work IDs sharing generation/head/base | Separate operation keys; no cross-work disposition reuse |
| Revoked directive / unavailable paginated evidence | Fail closed; bounded retry and pause |
| Feature-only completion / XXL missing qualified review | No automatic promotion across boundary |

## Alternatives, decisions, and default-off rollout

Reject "workflow succeeded implies ready" and unconditional assignment-time readiness:
both omit source/task/head binding. Manual scoped recovery remains valid but is not
acceptance of an automatic completion mechanism.
Prefer extending existing approval/decomposition/delivery helpers over a second authority
engine. Worker transport, durable surface, producer binding and race handling remain
owner decisions, not invented platform guarantees.

Runtime prerequisites still missing: approved finalized contract and PRD where required
by intake, trusted agent/local identity, complete retained candidate lookup,
enforceable downstream receipt gate (#3672), durable coordination proof, fixtures,
permission/race review, and separately authorized implementation.
Stage 0 is this documentation with runtime default off. Stage 1 runs read-only shadow
reconciliation. Stage 2 uses disposable fixtures. A separately authorized bounded pilot
may promote only proven identities after owners accept evidence; no queue capability
is enabled here. Stop on any stale promotion, ambiguous competition, or authority drift.
Rollback disables the new promotion path and preserves receipts/drafts for existing
manual scoped recovery; it must not auto-close sources or retroactively approve work.
