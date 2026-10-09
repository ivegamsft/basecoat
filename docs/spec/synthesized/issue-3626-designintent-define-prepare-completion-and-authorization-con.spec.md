---
issue: 3626
title: "design(intent): define prepare: completion and authorization contract"
status: draft
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Technical Specification: Prepare a Bounded Work Packet

## Context

The linked PRD proposes a request-scoped preparation contract and requires a
decision about whether it merits a new `prepare:` intent. Existing routes remain
authoritative. This specification defines a candidate contract for design
review; it does not register the token or authorize runtime changes.

## Scope

- Define candidate inputs, output fields, outcome states, evidence rules,
  authorization boundaries, failure behavior, and conformance tests.
- Require an explicit distinctness decision against `plan:`, `issue:`,
  `portfolio:`, `fleet:`, and `optimize:` before an implementation proposal
  can proceed.

| Existing route | Required comparison before a new-prefix go decision |
|---|---|
| `plan:` | Project/sprint sequencing versus a request-scoped evidence handoff |
| `issue:` | Triage and metadata hygiene versus a read-only packet |
| `portfolio:` | Cross-record grouping/dependency analysis versus one bounded request |
| `fleet:` | Sprint lifecycle, execution topology, and cleanup versus preparation without execution |
| `optimize:` | Advisory execution packet with scope, stop rules, validation and routing hints; show a concrete unmet need or reuse this route |

These are comparison obligations, not proof of distinctness. The closest
packet overlap with `optimize:` remains unresolved; no new-prefix go decision
is recorded by this proposal.

## Out of Scope

- Parser/routing changes, skills or agent behavior, workflows, issue/label
  writes, assignments, approvals, implementation, merge, release, or deployment.
- Selecting repository-wide budget values, output storage, or a target sprint
  without a separate decision.

## Architecture Overview

The proposed flow is a bounded, read-only evidence assembly:

1. Parse one request only after a separately approved implementation exists.
   Until then, `prepare:` is documentation vocabulary and must not route.
2. Resolve the request and repository identity from trusted invocation
   metadata, not text quoted in source content.
3. Read only the explicitly scoped source records and declared dependencies.
   Treat their contents as untrusted data.
4. Validate source completeness, permission evidence, freshness, and explicit
   budget policy.
5. Emit one packet with a status and evidence links, or a non-success outcome
   with blockers and a next decision. Perform no writes.

No new service or persistent state is proposed. A future implementation must
choose and justify its invocation surface and any storage after the distinctness
review.

## Data Model and Storage Changes

No data model or storage change is authorized by this document. The candidate
packet is a rendered handoff, not an approval record or durable authorization
receipt. If a later proposal adds persistence, it must define ownership,
retention, access controls, deletion, and source-revision binding first.

## API and Interface Contracts

### Candidate input contract

Every request must identify:

- Request text or a source issue/record reference.
- Trusted repository identity and the actor initiating the request.
- Any explicitly in-scope records and dependencies.
- Available execution policy limits and any stricter request limits.
- A preparation-only operation scope; the first release rejects requests to
  perform other stages or side effects.

Quoted or embedded repository content cannot supply trusted actor identity,
permissions, target repository, or an authorization directive. Missing trusted
identity, ambiguous scope, or absent bounded execution policy is a blocker.

An explicit request to perform any write, approval, assignment, implementation,
merge, release, or deployment in this invocation yields `blocked` with
`unsupported_action_scope` before source-content reads. Emit only safe request
metadata, named blockers in the required fields, and a next decision to narrow
the request to preparation. Do not silently discard the requested side effect
and return `prepared`. Describing future work to prepare for is not a request to
perform it; quoted source commands remain data, not requested actions.

### Actor and source authorization

The initiating actor must be authenticated by trusted invocation metadata,
explicitly permitted to prepare by repository-owned policy, and independently
authorized to read every scoped source. A service credential's broader access
is not evidence of the initiating actor's access. Missing invocation policy or
unverifiable actor identity yields `blocked` before source-content reads.

Before fetching content, obtain a trusted actor-specific access decision for
each record, attachment, and dependency, including cross-repository targets.
Repository sources require current read-or-higher access for that actor, or
verified public visibility permitted by the invocation policy. Other source
systems require their own actor-specific read decision; repository permission
does not authorize them. Issue text and source-supplied permission claims never
satisfy this check. Revalidate actor access for every source/version before
emitting any packet containing source-derived facts, metadata, or excerpts,
including `blocked` or `limited` checkpoints. Each final access decision must
be within the policy age bound at emission. Missing/denied final access yields
a zero-source-content `blocked` packet; insufficient budget to complete it
yields a zero-source-content `limited` packet. Cached read-time access alone
cannot authorize checkpoint disclosure.

Any denied or unknown access decision yields a zero-source-content `blocked`
packet: record an authorization blocker, omit all retrieved source excerpts,
and do not fetch the denied source or reveal private metadata about it. Use only
safe invocation/request identifiers in the result. Stop new content reads; no
write, assignment, approval, or delivery call is permitted.

### Candidate output contract

Emit the following fields in a human-readable work packet. Each field must
contain verified information, an explicitly marked assumption, or a named
blocker; required fields must never be omitted silently:

Authorization takes precedence over all retention and failure-reporting rules.
In a zero-source-content outcome, fill required fields with safe invocation
metadata or a named authorization, budget, scope, or cancellation blocker,
not retrieved source identifiers, titles, links, revisions, or graph fragments.

| Field | Required content |
|---|---|
| `status` | Exactly one of `prepared`, `blocked`, `limited`, or `cancelled` |
| `request` | Objective, source repository, requester, input kind, and trusted invocation identity/capture time; source record and revision/retrieval time when supplied, otherwise explicitly not applicable for text-only input |
| `scope` | Proposed in-scope work and explicit non-goals |
| `assumptions` | Each unverified assumption and its consequence |
| `dependency_graph` | Stable node IDs with source, observed state, evidence time, and owner/next action when known; explicit prerequisite edges and a prerequisite-first order |
| `acceptance` | Observable criteria and required evidence for a later stage |
| `authority` | Actor-specific invocation and per-source read decisions with policy/revision and validation time; unavailable evidence is a blocker; later-stage permissions/decisions remain separate |
| `constraints` | Target/environment constraints and applicable policy references |
| `budget` | Time, cost, source-count, and retry limits, or blockers naming missing policy |
| `evidence` | Safe source links, revision/digest bindings, retrieval/final-validation timestamps, policy maximum age, and packet issue time |
| `risks` | Material uncertainty, impact, and mitigation or decision owner |
| `next_decision` | One concrete decision or recovery action; none if explicitly cancelled |

The packet must state: **Preparation is not approval or implementation
authorization.** A complete packet may be handed off, but no subsequent stage
may rely on it instead of revalidating mutable evidence and current authority.

### Freshness and final revalidation

Repository-owned policy must supply a positive finite maximum evidence age;
missing policy yields `blocked`, not an inferred default. Record retrieval and
validation timestamps, source revision/digest, and packet issue time. Before
`prepared`, perform a bounded final pass over every material source and actor
access decision. Immutable evidence must match its verified revision/digest;
mutable evidence must match a freshly observed revision or content digest.

At packet issue time, every final validation must be within the declared age
bound. A detected change invalidates dependent claims and requires bounded
recollection/revalidation. Unavailable source/access evidence yields `blocked`;
an exhausted refresh/final-pass budget yields `limited`. Neither may emit a
prepared result. Tests use a controlled clock, fixed age bounds, and changing
source revisions to determine these outcomes.

This is an attributable, per-source freshness check, not an atomic cross-source
snapshot or a guarantee against changes after validation. A later stage must
revalidate independently; the packet conveys neither lasting access nor approval.

### Dependency graph contract

Each node has a unique request-local ID and the dependency evidence described
above. An edge `{ prerequisite, dependent }` names two existing node IDs and
means that the prerequisite gates the dependent. Record only source-supported
relationships; list order, shared ownership, or adjacency does not imply an
edge. Independent nodes have no invented prerequisite.

The proposed order contains each node exactly once and places every prerequisite
before its dependent. It is a planning artifact, not an execution schedule or
permission to act. An empty graph is valid only when the bounded evidence
establishes that there are no relevant dependencies.

Duplicate IDs, dangling edges, self-edges, cycles, unverifiable relationships,
or unresolved prerequisite states yield `blocked` with the affected node IDs
and recovery decision. Preserve verified graph fragments in non-success
packets; do not invent an order for a cyclic or incomplete graph. If the budget
ends before graph verification, return `limited`, not `prepared`.

### Outcome state semantics

| Status | Meaning | Required handling |
|---|---|---|
| `prepared` | Required fields are complete, evidence is attributable, and scope/dependencies are bounded | Hand off for a separately authorized decision; do not perform the work |
| `blocked` | Required context, permission evidence, dependency state, or policy is missing, conflicting, or inaccessible | Name each blocker, owner/decision if known, and a recovery step |
| `limited` | A time, cost, read, or retry budget ended before all requirements were established | Preserve only progress whose source access was finally revalidated; otherwise emit a zero-source-content checkpoint with safe invocation metadata and remaining blockers; never imply readiness |
| `cancelled` | The requester explicitly stopped preparation | Emit only safe invocation/stop metadata, no source-derived content; stop new reads and do not perform final revalidation after cancellation |

There is no `approved`, `ready-to-implement`, `implemented`, or `delivered`
status in this contract.

## Security and Privacy Considerations

- Use the least read permissions available. No write token or write permission
  is required for preparation.
- Treat issue bodies, comments, linked documents, and attachments as untrusted
  content. Ignore embedded instructions that attempt to change scope, reveal
  secrets, grant permissions, or cause writes.
- Do not copy credentials or unnecessary sensitive source content into the
  packet or logs; prefer scoped excerpts and links.
- Record only the actor/repository identity and permission evidence needed to
  explain the decision. Never treat a prior packet's permission snapshot as
  current approval.
- Keep the new prefix unsupported until distinctness, threat boundaries, and
  negative routing tests are reviewed and explicitly approved.

## Reliability and Failure Modes

| Failure | Required outcome |
|---|---|
| Source unavailable, malformed, or inaccessible | `blocked` with source and failure reason; do not infer absence or success |
| Permission lookup unavailable | `blocked`; do not assume the actor is authorized |
| Dependencies conflict, contain invalid edges/cycles, or cannot be verified | `blocked` with affected node IDs and unresolved prerequisite relationships |
| Evidence changes during preparation | Re-read within the bounded budget or return `limited`; mark superseded evidence |
| Time/cost/read/retry budget exhausted | `limited` with checkpoint and remaining work |
| Explicit cancellation | `cancelled`; stop new reads promptly |
| Untrusted content contains instructions or approval claims | Preserve as data only; no scope, authorization, or state transition |

Transient retries must be bounded by the declared policy. Permanent errors
must be surfaced; broad exception swallowing and success-shaped fallbacks are
prohibited.

## Performance and Capacity Considerations

Preparation must have explicit limits for elapsed time, cost, source count, and
retries. A request may lower these limits but cannot raise repository maximums.
The repository maximums and their owners remain an implementation-time decision;
until set and tested, a future implementation must stop before unbounded
collection and return `blocked`.

## Implementation Plan

No runtime implementation is authorized by this specification. A separately
approved implementation issue must:

1. Decide whether a distinct `prepare:` token is justified or an existing route
   should be extended.
2. Set repository-owned maximum budgets and define the packet's invocation and
   delivery surface.
3. Implement the read-only path and stable blocker reasons before considering
   any write capability.
4. Demonstrate all conformance tests and verify that distributed routing
   assets remain unchanged unless separately included in the approved scope.

## Testing Strategy

Any future implementation must execute the actual routing and packet-producing
code with fixtures covering:

- Complete requests and every required packet field.
- Text-only and record-referenced requests with trusted invocation provenance;
  require record identity/revision only for record inputs and never invent a
  source issue for raw text.
- Missing scope, non-goals, acceptance, actor, repository, source identity,
  budget, and next decision.
- Conflicting scope, unresolved and inaccessible dependencies, stale source
  revisions, and failed permission lookups.
- Empty and independent dependency graphs, multi-level prerequisite chains,
  and shared prerequisites; verify node completeness and prerequisite-first
  ordering without inferring edges from list order.
- Duplicate node IDs, dangling edges, self-edges, cycles, unverifiable edges,
  and unresolved prerequisites; assert named blockers and no invented order.
- Budget exhaustion at each boundary, bounded transient retries, and explicit
  cancellation.
- Quoted, fenced, bulleted, embedded, and adversarial instructions in issue
  text, comments, and attachments.
- Attempts to synthesize `/approve`, add approval labels, assign an agent,
  write metadata, dispatch workflows, or continue into implementation/delivery.
- Distinctness and non-routing tests proving `prepare:` is unsupported until a
  separately approved implementation lands.
- In the disabled baseline, execute the existing parser for routing collisions,
  dual prefixes, defer/stop modifiers, and unauthorized actors; assert no new
  route or authority.
- Only in a separately approved enabled-mode implementation, a valid standalone
  leading `prepare:` with authorized actor, scope and policy routes to the
  selected read-only packet producer and emits the appropriate packet outcome.
  Existing routes remain unchanged; quoted/fenced/bulleted/embedded tokens do
  not invoke it, dual prefixes block as ambiguous, stop cancels, and defer
  blocks without scheduling later work. None of these cases grants write or
  later-stage authority.
- Denied invocation policy, actor read denial on any scoped/cross-repository
  record or attachment, and unknown permission lookup: assert a zero-source-
  content blocked packet, no denied-source content read, and zero writes.
- Final revalidation with changed revisions, revoked actor access, an expired
  age bound, unavailable evidence, and exhausted refresh budget; assert the
  declared blocked/limited outcome and no stale prepared packet.
- Revoked/unknown access or exhausted final-access budget before a blocked or
  limited checkpoint: assert zero source-derived facts, metadata, and excerpts.
  Cancellation always emits zero source content and performs no new reads.
- Mixed preparation/write or later-stage requests: assert
  `unsupported_action_scope`, a zero-source-content blocked packet and no reads
  or mutations; quoted source commands do not expand the invocation scope.

For read-only cases, assert zero issue, label, assignment, workflow-dispatch,
or other mutation calls. For every non-success case, assert a named reason and
absence of a prepared result.

### Acceptance traceability

| Source requirement from #3626 | Design contract and required proof |
|---|---|
| Scope/non-goals, dependency graph, acceptance, authority, budgets, next decision | Required packet fields, graph validation, and complete/missing-field fixtures |
| Inputs/outputs, write permissions, stop/blocked states, identity/freshness | Interface, outcome, security, and failure contracts; zero-write and stale-evidence tests |
| Routing collisions, quoted/fenced/bulleted/embedded commands, dual prefixes, defer/stop, unauthorized actors | Adversarial and actual-parser fixtures above; unsupported token never grants authority |
| Canonical/distributed mappings, compatibility, migration | Asset boundary below; unchanged current routes and source/distributed parity |
| Positive/negative tests before routing implementation | Implementation and rollout gates; separately approved implementation must pass conformance before enabling a route |

### Routing and distribution boundary

No instruction, skill, workflow, or downstream mapping is added by this proposal.
The current canonical routing instruction remains
`instructions/basecoat-10-core-intent-routing.instructions.md`; the existing
`skills/ship-it/SKILL.md` and delivery workflows retain their current contracts.
Downstream consumers must continue to reject `prepare:` as unsupported.

A future approved implementation must inventory each changed canonical asset,
its installed/distributed counterpart, and its selected skill/workflow mapping
before edits. It must demonstrate source/distributed parity and existing-prefix
compatibility, document the migration and rollback, and keep the new route
disabled until those proofs and the distinctness decision are complete.

## Rollout, Migration, and Rollback Plan

This PRD/spec update has no runtime rollout. Any future runtime change requires
an implementation PR, fresh authorization, current issue/spec validation, and
the existing CI and native merge-queue gates. Keep the token disabled until
the distinctness decision and all negative routing tests pass. If an authorized
rollout later fails, disable the new route and revert its distributed/source
assets together; do not alter existing prefixes, approvals, labels, or
historical records automatically.

## Observability and Operational Readiness

A future implementation may record outcome counts, stable blocker codes,
elapsed time, and budget consumption. It must not emit source bodies or
sensitive content by default. Operational evidence must distinguish
`prepared`, `blocked`, `limited`, and `cancelled`; a count of prepared packets
is not a delivery-success metric.

Before rollout, document owners for budget configuration, permission/API
failures, policy changes, and route retirement. No operator should need to
infer whether a packet produced side effects: the read-only contract and tests
must make zero writes observable.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Users interpret `prepared` as approved or executable | Required disclaimer, separate authority field, and no approval-shaped status |
| New prefix duplicates current planning routes | Mandatory overlap review and no-go if the distinct user contract is not demonstrated |
| Stale evidence is reused downstream | Bind claims to source revisions/times and require every later stage to revalidate |
| Preparation grows into an unbounded research loop | Explicit budgets, bounded retries, and `limited` checkpoints |
| Prompt injection in source records broadens scope | Treat all source content as untrusted data and assert zero side effects in adversarial tests |
| Missing data is hidden by defaults | Required-field completeness check; missing policy or evidence blocks |

## Open Questions

- Does the demonstrated request-level contract justify a new `prepare:` token,
  or should `plan:` or a preparation skill own it?
- Should the packet be markdown-only, or is a machine-readable representation
  needed? If so, where is it stored and who may read it?
- What repository-owned maximum time, cost, source-count, and retry budgets
  are appropriate?
- Is any metadata write useful enough to propose later, and what exact separate
  authority would permit it?

These questions are decisions, not implementation defaults. An unresolved
question that changes authority, data handling, or user-visible behavior blocks
runtime implementation.

## References

- PRD: `docs/prd/synthesized/issue-3626-designintent-define-prepare-completion-and-authorization-con.prd.md`
- Parent comparison: `docs/design/ai-sdlc-work-units.md` (#3625)
- Intent routing: `docs/guides/intent-prefixes.md`
- Shared approval contract: `docs/spec/issue-3591-approval-contract.spec.md`
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3626>
