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
