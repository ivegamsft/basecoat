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
| `spec:` | PRD/spec synthesis, `design:` | Reviewable specification with traceable fixtures | Read-only; named artifact writes only with explicit scope | Implementation authority decision | [#3627](../spec/specification-work-unit.spec.md) |

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
