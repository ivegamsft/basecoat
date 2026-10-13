# Intent Work-Unit Contracts

Status: proposal reference. Every candidate verb in this document is
**unsupported syntax**. Publishing a contract here does not register a prefix,
alias, router, skill mapping, workflow, approval label or agent assignment.
Supported routes remain defined by
[the intent guide](../guides/intent-prefixes.md) and the canonical
[`basecoat-10-core-intent-routing`](../../instructions/basecoat-10-core-intent-routing.instructions.md)
instruction. Naming and distinctness status is owned by the
[decision matrix](../design/ai-sdlc-work-units.md#canonical-naming-and-decision-matrix).

This file is the single home for the per-verb completion and authorization
contracts proposed in #3626-#3631. Each verb section is the reviewable summary
of its pinned spec; the spec remains the detailed source of truth.

## Contract overview

| Candidate | Supported route today | Completion unit | Default effect | Hands off to | Spec |
| --- | --- | --- | --- | --- | --- |
| `prepare:` | `plan:`, `issue:`, `portfolio:`, `fleet:`, `optimize:` | Bounded, evidence-bound work packet | Read-only | Specification or authorization decision | [#3626](../spec/synthesized/issue-3626-designintent-define-prepare-completion-and-authorization-con.spec.md) |
| `spec:` | PRD/spec synthesis, `design:` | Reviewable specification with traceable fixtures | Read-only; named artifact writes only with explicit scope | Implementation authority decision | [#3627](../spec/specification-work-unit.spec.md) |
| `build:` | `feature:` | Approved scope implemented and validated for an exact head | In-scope source and test writes plus draft PR after implementation authority | Review, then separate delivery authority | [#3628](../spec/synthesized/issue-3628-designintent-define-build-completion-and-authorization-contr.spec.md) |
| `review:` | `audit:`, `investigate:`, `rca:` | Evidence-bound findings and disposition for a declared scope | Read-only | Finding owners and a separate approval decision | [#3629](../spec/synthesized/issue-3629-designintent-define-review-completion-and-authorization-cont.spec.md) |
| `deliver:` | `ship-it:`, `spec-2-prod:` | Approved scope verified at the exact production target | Existing governed delivery controls with live revalidated authority | Close-out and learning; publication step uses `ship:` | [#3630](../spec/synthesized/issue-3630-designintent-define-deliver-completion-and-authorization-con.spec.md) |
| `ship:` | `release:`, `deploy:` | Validated immutable artifact published and verified at its destination | Publication through existing release gates with separate authority | `deploy:` rollout and delivery verification | [#3631](../spec/synthesized/issue-3631-designintent-define-ship-completion-and-authorization-contra.spec.md) |

## Shared contract

Every verb section uses the same seven subsections so contracts can be
compared and checked mechanically by
[`tests/intent-work-unit-contract-tests.ps1`](../../tests/intent-work-unit-contract-tests.ps1).

| Subsection | Required content |
| --- | --- |
| Inputs | Source identity (repository, issue or record, exact revision or digest), scope and non-goals, actor and live authority evidence, budgets |
| Completion evidence | The observable evidence that ends the work unit and the success states that are allowed |
| Authorization boundary | Permitted reads and writes, plus a `Never implied:` list of effects the verb cannot perform |
| Failure and hold states | Named non-success states with required handling; none may be reported as success |
| Handoff | What the next verb or decision receives, and what it must revalidate |
| Distinctness decision | Existing route that remains authoritative and the open decision |
| Verification fixtures | Positive and negative fixtures required before any routing is enabled |

### Shared rules

- A candidate token, label, generated comment, green check or merged document
  never manufactures consent. Issue approval is not delivery consent.
- Bind every conclusion to exact source, artifact, head or target identities
  and their capture time. Changed identity invalidates dependent evidence;
  there is no implied global freshness window.
- Missing, ambiguous or inaccessible input yields a named blocker, never a
  success-shaped default. Retries stay within the recorded budget and never
  reset it.
- Resume re-reads live actor permission, scope, dependencies, identities and
  budget before the next side effect. Stale evidence is never inherited as
  current.
- Solo-dev remains autonomous through XL after explicit intake and delivery
  authority. XXL and other explicit human boundaries remain. Parallel
  preparation never implies concurrent merges or expanded scope.
- Quoted, fenced, bulleted or embedded text is data, not a directive.

### Disabled-baseline evidence

The [approval contract suite](../../tests/approval-contract-tests.cjs)
executes the production delivery parser against every candidate verb in
leading, quoted, fenced, bulleted, embedded and collision shapes
(`P3725-candidate-<verb>-<shape>`). Each yields `none`, and the resolver does
not run. The work-unit contract suite fails if a documented candidate is
missing from that fixture list or appears as a supported route row.

## `prepare:` preparation

Proposal for #3626. Pinned spec:
[`issue-3626-...-prepare-...spec.md`](../spec/synthesized/issue-3626-designintent-define-prepare-completion-and-authorization-con.spec.md).
Bound and make work actionable before implementation.

### Inputs

Request text or a source issue or record reference, trusted repository and
actor identity from invocation metadata, explicitly in-scope records and
dependencies, repository-owned budget limits (a request may lower but never
raise them), a positive finite evidence age bound, and a preparation-only
operation scope. Source content cannot supply actor identity, permissions,
target repository or authorization. Before any source read, the actor must be
authenticated and explicitly permitted by repository-owned policy to invoke
preparation; per-source read access alone is insufficient. Each scoped source
also needs a current actor-specific read decision; a service credential's
access is not evidence.

### Completion evidence

One human-readable packet with `status`, `request`, `scope`, `assumptions`,
`dependency_graph`, `acceptance`, `authority`, `constraints`, `budget`,
`evidence`, `risks` and `next_decision`. Each field holds verified data, a
marked assumption or a named blocker. Success is `prepared` only after a
bounded final revalidation of every material source and access decision
within the age bound. The dependency graph uses unique node IDs, explicit
source-supported prerequisite edges and a prerequisite-first order. The packet
states: Preparation is not approval or implementation authorization.

### Authorization boundary

Read only the scoped sources and declared dependencies, using least privilege.
No write permission is required or used. A request that also asks to write,
approve, assign, implement, merge, release or deploy is blocked as
`unsupported_action_scope` before source-content reads.

Never implied: issue or label mutation, approval directives or labels, agent
assignment, workflow dispatch, implementation, merge, release, deployment or
any lasting access grant.

### Failure and hold states

| State | Required handling |
| --- | --- |
| `blocked` | Missing, conflicting or inaccessible context, permission, dependency, policy or age bound; invalid graph (duplicate, dangling, self-edge, cycle); a mixed write or later-stage request is `unsupported_action_scope`; name each blocker and recovery step. Denied or unknown access emits zero source content |
| `limited` | Time, cost, read, retry or final-pass budget ended; checkpoint keeps only finally revalidated progress; never implies readiness |
| `cancelled` | Requester stopped; emit only safe invocation metadata and perform no new reads |

There is no `approved`, `ready-to-implement`, `implemented` or `delivered`
status in this contract.

### Handoff

A `prepared` packet hands its `next_decision` to a specification
(`spec:` contract) or an authorization decision. No later stage may rely on
the packet instead of revalidating mutable evidence and current authority;
it conveys neither approval nor lasting access.

### Distinctness decision

`plan:`, `issue:`, `portfolio:`, `fleet:` and `optimize:` remain
authoritative. The closest overlap, the `optimize:` execution packet, is
unresolved; no new-prefix go decision is recorded.

### Verification fixtures

A future implementation must cover complete and missing-field packets,
text-only and record inputs, empty, independent, chained and shared-prerequisite
graphs, invalid graphs with no invented order, budget exhaustion at each
boundary, cancellation, adversarial source instructions, synthesized approval
or write attempts (`unsupported_action_scope`), denied access with zero source
content, and final revalidation with changed revisions, revoked access or an
expired age bound. Every read-only case asserts zero mutation calls.

## `spec:` specification

Proposal for #3627. Pinned spec:
[`specification-work-unit.spec.md`](../spec/specification-work-unit.spec.md).
Produce an executable specification without authorizing implementation.

### Inputs

Repository, source issue or authorized request, source body revision hash,
scope and non-goals, requested artifact paths, requester and authority
evidence, and explicit time, input and retry bounds. Quoted examples and tool
output are not independent requests. An inaccessible source, absent actor
evidence, unclear scope or unbounded request is blocked.

### Completion evidence

A packet with `source_identity`, `scope`, `authority_evidence`,
`artifact_inventory`, `artifact_revision`, `requirements`, `decisions`,
`unknowns`, `validation`, `outcome`, `remaining_budget` and
`resume_checkpoint`. Success is `Reviewable`: linked artifacts are consistent,
every requirement names its clause, positive and negative fixture, evidence
source and pass threshold (R1-R6), and open decisions are named. Executed
validation commands are recorded with results; a proposed command is not an
execution. Specification completeness is reported separately from runtime
acceptance.

### Authorization boundary

Without explicit artifact scope, read and return a proposed diff only. With
it, write only the named PRD/spec paths, an isolated branch or worktree,
attributed commits and a draft artifact PR whose file inventory is bound to
the intake contract.

Never implied: approval fields or labels, approval directives, agent
assignment, runtime asset edits, ready promotion, merge or release requests,
or overwriting semantic conflicts and unrelated edits.

### Failure and hold states

| State | Required handling |
| --- | --- |
| Blocked | Name the unmet scope, authority, dependency, conflict or artifact check, its owner and recovery action |
| Limited | Partial artifact state, remaining budget, last safe revision and outstanding effects; not success |
| Cancelled | No further writes; retain the checkpoint and do not silently revert external work |

Lint failure, semantic conflict, stale identity or exhausted budget never
publishes or overwrites. A lost publication response requires read-back of the
exact branch or PR before another write.

### Handoff

A reviewable specification hands off to the existing approval and
implementation handoff (#3593/#3592). The receiver revalidates source and
artifact digests and current authority; an old `/approve` never binds to a
changed artifact, and a merged spec does not assert that its tests pass.

### Distinctness decision

Existing design, PRD and spec authoring plus the issue-to-spec synthesis
workflow remain authoritative. No `spec:` token is selected; a concept or
documentation term is preferred unless a distinct boundary is demonstrated.

### Verification fixtures

Before activation, actual-parser fixtures must show: supported design requests
unchanged; `spec:` unsupported with no write or approval inference; quoted,
fenced, bulleted or embedded examples not executed; lookalike, empty goal or
dual prefixes rejected without mutation; `later`, read-only or stop modifiers
deferring; revoked actor or changed evidence blocking; and repeated requests
reading back exact identity without duplicate writes or budget reset.

## `build:` implementation

Proposal for #3628. Pinned spec:
[`issue-3628-...-build-...spec.md`](../spec/synthesized/issue-3628-designintent-define-build-completion-and-authorization-contr.spec.md).
Implement approved scope and prove it without merge or deployment consent.
Compilation or packaging alone is a validation activity, not this work unit.

### Inputs

Repository, source issue, approved spec path with immutable revision or
digest, approved scope and non-goals, authorized actor with live evidence,
base and head identities, dependencies and execution budgets. Authority and
dependencies are re-read before writes and on resume. Missing, revoked,
wrong-repository or changed-scope evidence is blocked. A compile-only or
package-only request must be disambiguated explicitly rather than treated as
implementation.

### Completion evidence

Changed-file inventory within approved scope, spec and issue identities,
base and head SHA, exact positive and negative test commands with results,
and a reproducible resume checkpoint. `Implemented` means an in-scope diff and
draft handoff exist; `Validated` means tests and checks passed for that exact
head. A green run for a different head is never reused.

### Authorization boundary

After valid implementation authority, write only named in-scope source and
test files, an isolated branch or worktree, attributed commits and a draft PR.
Existing feature-origin provenance and plan/log-first contracts apply.

Never implied: ready promotion, auto-merge, merge, tagging, deployment,
approval labels or directives, delivery consent from green checks, or making
`build:` an alias for `ship-it:`.

### Failure and hold states

| State | Required handling |
| --- | --- |
| Blocked | Name the unmet authority, dependency, scope or validation condition and the recovery action |
| Paused | Durable checkpoint, remaining budget and outstanding effects; not success |
| Cancelled | Stop new side effects; do not assume permission to revert external changes |

Changed scope or spec revision invalidates affected test evidence.

### Handoff

A validated draft PR hands off to review and to a separately validated
delivery directive (`deliver:` contract or existing `ship-it:`). The receiver
revalidates head, spec identity and live authority. Solo-dev needs no routine
human review through XL once applicable authority exists; XXL and other
explicit human boundaries remain.

### Distinctness decision

`feature:` remains authoritative and is recommended. `build:` is rejected for
now as ambiguous with compilation; `implement:` is a candidate only if
distinctness is demonstrated. No alias is added.

### Verification fixtures

Before adopting either prefix, actual-parser fixtures must cover standalone
mixed-case input, empty goals, quoted, fenced, bulleted and embedded examples,
lookalikes, dual authoritative prefixes, defer and stop modifiers,
unauthorized actors and compile-only ambiguity. Until adoption, both
candidates must remain unsupported, and behavior fixtures must show
out-of-scope edits rejected and stale-head evidence refused.

## `review:` assessment

Proposal for #3629. Pinned spec:
[`issue-3629-...-review-...spec.md`](../spec/synthesized/issue-3629-designintent-define-review-completion-and-authorization-cont.spec.md).
Assess artifacts and outcomes without changing authorization.

### Inputs

An explicit artifact set, question and exclusions (no inferred
repository-wide scope); artifact identity with exact revision or content
digest; a comparison baseline or a recorded `not applicable`; the target
environment, branch, release or other subject, or an explicit `not
applicable` when none exists; evidence sources with capture time and their
freshness policy; trusted actor identity and live authority evidence from
invocation metadata; a bounded time, read and retry budget; and read access to
the named evidence only. Caller-supplied identity or permission claims are not
evidence.

### Completion evidence

A report in which every in-scope item has a finding or an explicit
non-success disposition. Each finding records a stable identifier, artifact
and revision, severity and confidence from a vocabulary selected before
implementation, evidence references with capture times, rationale and a
disposition (`actionable`, `not reproduced`, `acceptance recorded` with its
authorized source, or `unresolved`). The report states coverage, unexamined
items, freshness and blockers. `Complete` requires all of this; partial
evidence never claims repository-wide completeness.

### Authorization boundary

Read the requested artifacts and named, necessary evidence. Return the report
to the requester; persist it only to an explicitly specified destination under
separately documented permission. The assessor cannot accept risk.

Never implied: posting an APPROVED review or any comment, resolving threads,
editing source, creating branches or PRs, changing labels, assignees or
issues, merging, releasing, deploying or modifying authorization. Current
solo-dev advisory-review policy is unchanged.

### Failure and hold states

| State | Required handling |
| --- | --- |
| Blocked | Ambiguous scope, unavailable or stale evidence, mismatched identity, permission change or unsupported write request; record the unmet condition and unexamined scope |
| Partial | Partial source access or exhausted budget; report coverage and checkpoint, never success |
| Stopped | Explicit stop, defer or conflicting directive; no further reads or writes |

Undefined freshness rules, an unreadable source or a new revision mark
dependent findings unknown or stale; no current-state conclusion is drawn.

### Handoff

Findings hand off to their owners: `actionable` items to implementation
(`build:` contract or existing `feature:`/`bug:`), and the report to a human
or authorized approver who decides separately. Resume rechecks scope,
permissions, artifact identity, target, freshness and budget; stale findings
are never inherited as current.

### Distinctness decision

`audit:`, `investigate:` and `rca:` remain authoritative for their documented
purposes, and GitHub review submission remains a separate authenticated
decision. `review:` is considered only after a distinct, non-alias need is
demonstrated.

### Verification fixtures

A future implementation must show: a standalone candidate with explicit scope
routes only if approved and registered; quoted, fenced, bulleted or embedded
text does not execute; a dual prefix is rejected with no side effect;
`defer`, `later`, read-only, no-changes and stop modifiers do not execute; an
actor who never had review authority is rejected before any read; requests to
submit APPROVED, change a label or edit source are blocked; missing revision,
wrong target, stale evidence or revoked access fail closed; and partial access
or budget exhaustion reports partial coverage, never success.

## `deliver:` delivery

Proposal for #3630. Pinned spec:
[`issue-3630-...-deliver-...spec.md`](../spec/synthesized/issue-3630-designintent-define-deliver-completion-and-authorization-con.spec.md).
Complete approved scope through verified production as one governed intent.

### Inputs

A qualified live delivery receipt with actor, source comment or record and
current permission, re-fetched at each side-effect boundary; the source issue
with approved scope, non-goals and exact issue or spec revision; the exact
change, head or tree with dependencies, expected outputs, budget and stop
conditions; the destination repository, integration branch, release version,
deployment environment and target; and named acceptance checks with
target-specific production evidence. Caller assertions, generated text,
labels alone or stale receipts are rejected as authorization.

### Completion evidence

Checks bound to their commit, tree or integration tree, workflow run and
result; publication bound to immutable version, tag, source commit, artifact
digest and destination; production verification bound to the named target,
observed behavior and capture time. `Verified` is the only completion state:
exact approved acceptance evidence at the named target. A PR merge, issue
closure or dispatch event is not delivery.

### Authorization boundary

Read the approved issue, spec and receipt, declared dependencies, exact-head
checks, merge queue state and named release and production evidence. Write
only through existing authorized delivery controls (ship-it and spec-2-prod
gates, merge queue, release owners), preserving every gate. Parallel
preparation never permits concurrent merges or relaxed dependency ordering.

Never implied: applying approval labels, assigning an agent, altering issue
authority, expanding scope, skipping checks, review or XXL gates, bypassing the
merge queue, retargeting a release or deployment, or destructive rollback.

### Failure and hold states

| State | Required handling |
| --- | --- |
| Blocked | Revoked or stale authority, changed source, spec or dependency, failed or missing check, target mismatch, permission loss or explicit hold; stop before the next boundary and retain the checkpoint |
| Partial | Record completed and in-flight boundaries, blocker, unexamined scope and checkpoint; never label as delivered |
| Stopped | No new effects after the stop or cancellation; report irreversible and in-flight effects |

Delivery holds and dependency ordering stay effective. Rollback is never
implied; recovery needs separately authorized scope. Resume re-reads
authority, scope, spec, dependencies, head, target, checks and budget, and
invalidates evidence affected by changed identity.

### Handoff

Implementation inside delivery follows the `build:` contract; publication of
the validated immutable artifact follows the `ship:` contract or existing
`release:` gates; deployment follows `deploy:`. At `Verified`, the completion
ledger hands off to close-out and post-delivery learning, which grants no
further scope.

### Distinctness decision

`ship-it:` and `spec-2-prod:` and their control plane remain authoritative.
If `deliver:` would have the same route and effects, it is an alias and is not
added; a canonical rename versus scoped alias remains unresolved. Delivery is
an outcome, not a parallel-agent mode.

### Verification fixtures

A future route must show: standalone candidate with qualified current
authority routes only if registered and composes existing controls; missing
authority, issue approval only or a caller-supplied receipt is rejected before
side effects; quoted, fenced, bulleted, embedded or dual-prefix text does not
execute; defer, read-only and stop modifiers produce no effects; revoked
receipt, changed spec, blocked dependency or failed checks stop before the
next boundary; wrong target or failed production verification never claims
completion; and out-of-scope implementation or destructive rollback is
rejected.

## `ship:` publication

Proposal for #3631. Pinned spec:
[`issue-3631-...-ship-...spec.md`](../spec/synthesized/issue-3631-designintent-define-ship-completion-and-authorization-contra.spec.md).
Publish an already validated immutable release without expanding
implementation scope.

### Inputs

Qualified current permission or receipt for publication to the named
destination; repository, commit or tree, approved scope and validation run
identities; an immutable artifact digest with manifest, provenance and build
identity; the exact version and tag with their existing owner and policy; an
explicit destination (never a default); and the expected payload, evidence
source, capture time and freshness policy. Caller-supplied values are checked
against trusted source and publisher state. Undefined tag or version
ownership stops for a separate decision.

### Completion evidence

Validation bound to source commit, tree and run; the artifact bound to digest
and manifest; the release bound to exact version, tag and destination; and
verification bound to the published payload and capture time. `Published`
means the exact payload is verified at the named destination. A tag, merge,
dispatch marker or internal release record alone is not publication, and
production health is a separate deployment result.

### Authorization boundary

Read the named source, artifact provenance, current validation, release and
tag state, destination state and publication proof. Publish only after
separate authority and the existing release gate, for the immutable artifact,
exact version and tag, and exact destination. Deployment uses the existing
`deploy:` route and its own target authority.

Never implied: implementing code, rebuilding from changed source,
overwriting or moving a tag, retargeting a destination, creating approval,
skipping release checks, deploying, or claiming production health.

### Failure and hold states

| State | Required handling |
| --- | --- |
| Blocked | Missing or revoked authority, unclear owner, source or artifact mismatch, failed or stale validation, missing provenance, existing tag with different content, or destination mismatch; stop before any write |
| Uncertain | Timeout or unknown publisher result; query the exact target, version and digest before any retry and preserve uncertainty if undeterminable |
| Partial | Record each completed effect and checkpoint; partial release is never success |

A retry uses only the same immutable artifact, version, tag and destination
and relies on existing publisher idempotency; it never retargets an existing
version or tag. Recovery or rollback needs separate authority and preserves
published records. Resume revalidates authority, identities, publisher state,
freshness and budget.

### Handoff

If code is missing or the artifact is unvalidated, hand back to the `build:`
contract (or existing `feature:`) rather than implementing implicitly. After
`Published`, hand off to `deploy:` for target rollout and to the `deliver:`
contract or existing `ship-it:` ledger for production verification.

### Distinctness decision

`release:`, `deploy:` and `ship-it:`/`spec-2-prod:` remain authoritative.
`ship:` is added only if publication has a distinct unmet boundary, compared
against keeping `release:` and a `publish:` alternative; it is never
registered as an alias. If both are adopted, `deliver:` owns the whole outcome
and `ship:` only publication of a ready artifact.

### Verification fixtures

A future route must show: an approved standalone candidate for a validated
immutable artifact routes only if registered and composes current release
gates; no authority, ambiguous destination or unvalidated artifact is
rejected before any write; quoted, fenced, bulleted, embedded or dual-prefix
text does not execute; defer, read-only and stop modifiers publish nothing; a
tag already pointing to a different digest fails closed; a retry after
timeout inspects the exact existing target and never retargets; partial
publication never claims completion; and a request adding implementation or
deployment stops for separate scope.
