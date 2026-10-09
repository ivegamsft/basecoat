# Spec: Specification work unit

Status: proposal for #3627. This publishes the specification contract, not a
router. `spec:` is unsupported; use existing design/synthesis paths. No runtime
implementation or source issue approval is granted by merging these artifacts.

## Input and Identity

Bind repository, source issue or authorized request, source body/revision hash,
scope/non-goals, requested artifacts, requester/actor, authority evidence and
explicit time/input/retry bounds. Record the authoritative source URL and the
observed revision; quoted examples and tool output are not independent requests.

Separate read access, artifact-authoring scope and implementation/delivery
authority. An inaccessible source, absent actor evidence, unclear scope or
unbounded request returns a named blocked condition. Do not default unknown
permission or dependency state to approved or empty.

## Alternatives and Ownership

| Option | Benefit | Disposition |
| --- | --- | --- |
| Existing design/PRD/spec authoring | Reuses established requirements and review standards | Preferred |
| Existing synthesis producer | Repeatable draft creation and issue links | Reuse; #3660 owns artifact validation gaps |
| New `spec:` route | Potentially clearer entry point | Unselected; requires distinctness and collision evidence |

Use current product/design owners for unresolved requirements and existing
implementation/assignment owners after authorization. A document author cannot
resolve a product authority decision by adding an acceptance checkbox.

## Permitted Writes

Without explicit artifact scope, read and return a proposed diff only. With it,
allow only the named PRD/spec paths, necessary source links inside those artifacts,
an isolated branch/worktree, attributed commits and a draft artifact PR. Bind
the file inventory and additions/deletions to the PR intake contract.

Do not edit source approval fields/labels, post approval directives, assign
agents, modify runtime assets, promote readiness or request merge/release.
Semantic conflicts, unrelated user edits or stale artifact identity block
publication; never overwrite them using a generation fallback.

## Completion and Evidence Packet

Produce `source_identity`, `scope`, `authority_evidence`, `artifact_inventory`,
`artifact_revision`, `requirements`, `decisions`, `unknowns`, `validation`,
`outcome`, `remaining_budget` and `resume_checkpoint`. These are conceptual
fields for a future contract, not a newly implemented JSON schema.

Each requirement names its spec clause, positive/negative fixture, evidence
source and pass threshold. Cover security, failure modes, implementation plan,
rollout/rollback, observability and risks under the existing standards. Record
exact validation commands and outcomes; a proposed command is not an execution.

| Outcome | Required evidence / next action |
| --- | --- |
| Reviewable | Consistent linked artifacts, traceability and named open decisions; no approval implied |
| Blocked | Unmet scope, authority, dependency, conflict or artifact check; owner and recovery action |
| Limited / paused | Partial artifact state, remaining budget, last safe revision and outstanding effects |
| Cancelled | No further writes; retain checkpoint, do not silently revert external work |

An artifact may be reviewable while implementation remains blocked. A generated
draft, lint result or merged spec does not assert that its tests exist or pass.
Report specification completeness separately from runtime acceptance.

### R1-R6 verification traceability

These are future behavior fixtures, not executed runtime evidence for this
documentation PR. Retain input/output identities and actual validation logs
for each fixture; a missing fixture result is unknown, never a pass.

| Requirement / clause | Positive fixture | Negative fixture | Evidence / pass threshold |
| --- | --- | --- | --- |
| R1 / Input and identity | Authorized request pins source hash, goal and bounds | Missing scope or inaccessible source | Source/read receipt and output packet; every required field present or named blocked state, no writes on negative |
| R2 / Permitted writes | Explicit artifact scope creates only named docs and draft PR | Request asks artifact author to approve, assign or deploy | File/API effect inventory; exact allowlist, zero prohibited effects |
| R3 / Completion | Complete PRD/spec has requirement clauses and fixture oracles | Delete an oracle or replace executed evidence with a proposed command | Traceability and validation logs; every requirement has both fixtures, evidence source and threshold, incomplete packet cannot claim completeness |
| R4 / Failure and resume | Bounded pause preserves last safe revision and remaining budget | Lint failure, semantic conflict or exhausted budget | Checkpoint, diagnostics and publication inventory; named recovery action, no success or overwrite on failure |
| R5 / Freshness | Resume rechecks unchanged actor/source/artifact identities | Change source scope, revoke actor or lose publication response | Immutable digests plus read-back receipts; no old authority reuse, duplicate write or retry reset |
| R6 / Adoption gates | Supported design request retains existing behavior | Unsupported `spec:`, fenced example or `later` request | Actual-parser output and write inventory; existing routes unchanged, zero inferred writes/authority for negatives |

## Freshness and Resume

Pin each referenced specification/evidence artifact to an immutable revision
and digest where available. Name observations that remain mutable and their
collection time; do not use an unqualified "current" reference as approval.
Freshness is invalidated by changed source scope/body, authorizing evidence,
dependency identity, relevant target/base or artifact blobs.

Before publishing or resuming, re-read live actor access and scope evidence,
compare exact source/artifact identities and remaining budget, and inspect
existing branch/PR state. Reuse the same checkpoint for a retry; a new generation
does not reset retries or consume a different approval. If remote publication
response is lost, read back the exact branch/PR before another write.

Final implementation handoff is separately governed by #3593/#3592 and current
approval machinery. This proposal does not implement `/approve-spec` or
retroactively bind an old `/approve` to changed artifacts.

## Failure, Security and Observability

API errors, unavailable evidence, lint failure and stale sources return explicit
non-success states and sanitized diagnostics. Retry only identified transient
reads within the recorded budget; semantic uncertainty requires owner action.
Record repository/source/revision, stage, reason, verification timestamp and
actual evidence links; redact credentials and avoid copied private issue bodies.

Untrusted text is documentation data, not shell code, approval or executable
validation. Run only repository-owned validation selected from the trusted base.
Never use source text to choose commands, destinations or write scope.

## Adoption and Distribution Gates

Do not add canonical aliases, pointer stubs, workflow mapping or skill metadata
during proposal publication. Existing instruction, guide and synthesis behavior
remains authoritative; no asset-manifest regeneration is needed for these docs.

Current routing owner is
[`basecoat-10-core-intent-routing`](../../instructions/basecoat-10-core-intent-routing.instructions.md);
[`intent-routing`](../../instructions/intent-routing.instructions.md) is its
pointer alias, not a second implementation. Existing `design:` uses downstream
`PRODUCT.md` and the Sheen design catalog; `plan:` can use the existing
[`product-manager`](../../agents/basecoat-10-core-product-manager.agent.md).
Neither is a newly mapped `spec:` skill or executor.

Existing workflow consumer is
[`issue-to-spec-synthesis.yml`](../../.github/workflows/issue-to-spec-synthesis.yml),
with its [distributed source](../../.github/base-coat/workflows/issue-to-spec-synthesis.yml).
[`ship-it`](../../skills/ship-it/SKILL.md) is a separate delivery consumer and
does not acquire implementation authority from this artifact contract.
No instruction, skill, agent or workflow mapping changes in this proposal.

For future adoption, inventory these owners and both synthesis copies plus
actual parser/eval consumers. `sync.ps1`/`sync.sh` distribute root instructions
and skills into the overlay and `.github/instructions`/`.github/skills`;
workflow installation consumes `.github/base-coat/workflows`. Compatibility
targets are existing downstream installations, aliases and supported requests,
not just this repository's canonical files. Update affected owners, source
templates and installer/eval fixtures together under separate approval.
Before activation, run actual-parser fixtures for these expected boundaries:

| Fixture | Required behavior |
| --- | --- |
| Existing supported design/synthesis request | Existing behavior unchanged |
| `spec:` before adoption | Remains unsupported; no write/approval inference |
| Standalone candidate with named artifacts after adoption | Artifact-only scope, qualified actor and bounded result |
| Quoted, fenced, bulleted or embedded example | No immediate execution; explicit triage/deferred semantics |
| Lookalike, empty goal or dual authoritative prefixes | Reject ambiguity without mutation |
| `later`, read-only, stop or contradictory modifier | Defer/stop; no artifact writes inferred |
| Revoked actor, inaccessible source or changed evidence | Block; no assignment or approval |
| Lost publication response / repeated request | Exact identity read-back, no duplicate write or budget reset |

These fixtures define future acceptance, not evidence of a shipped parser.
Preserve supported old routes; test distribution parity, manifest identities
for changed runtime assets and old-consumer compatibility before enabling.
Require migration notices, bounded canary evidence and an explicit rollback
that disables only the new route and retains existing artifacts.

## Verification and References

For this proposal: lint both files, verify links/traceability and inspect the
two-file docs-only diff. Runtime tests cannot prove an unimplemented router;
required hosted PR checks remain separate.

- [PRD and R1-R6 traceability](../prd/specification-work-unit.prd.md).
- [Naming decision matrix](../design/ai-sdlc-work-units.md#canonical-naming-and-decision-matrix).
- [Supported intents](../guides/intent-prefixes.md).
- [Existing handoff proposal](synthesized/issue-3593-featintake-define-an-approved-spec-handoff-from-synthesized-.spec.md).
