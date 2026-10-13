---
issue: 3629
title: "design(intent): define review: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# Spec: design(intent): define review: completion and authorization contract

## Status and Authority

Proposal only; `review:` is unsupported syntax. This spec does not authorize
parser, workflow, runtime, approval, or metadata changes. Any implementation
requires a separately approved issue and implementation spec.

## Decision Boundary

| Question | Proposed contract |
| --- | --- |
| Purpose | Assess explicitly identified artifacts and report evidence-backed findings |
| Completion unit | Bounded scope with each requested artifact either assessed or explicitly listed as blocked/unexamined |
| Default effect | Read-only |
| Approval effect | None; findings are not a GitHub APPROVED review or delivery consent |
| Current route | Prefer existing `audit:`, `investigate:`, or `rca:` according to their documented purpose |
| Candidate route | Consider `review:` only after a distinct need and non-alias contract are demonstrated |

## Input Contract

| Field | Requirement |
| --- | --- |
| Scope | Explicit artifact set, question, and exclusions; no inferred repository-wide scope |
| Artifact identity | Repository/system, stable identifier or path, exact revision/content digest when available |
| Comparison | Exact baseline revision or named comparison; record when none is applicable |
| Target | Environment, branch, release, or other subject of the assessment; explicit `not applicable` when none exists |
| Evidence | Source, identifier/link, captured-at time, and applicable freshness policy |
| Authority | Read access to the named evidence only; identity or permission claims supplied by a caller are not evidence |

Missing or ambiguous scope, artifact identity, target, or required evidence is
a blocker, not a success-shaped default.

## Scope

Only inspect the declared artifact set and evidence necessary to answer the
declared question. Exclude implementation, remediation, approval, publication,
and unrelated backlog execution.

## Output Contract

Each finding records a stable finding identifier, artifact and revision,
severity and confidence using a vocabulary selected before implementation,
evidence references with capture times, concise rationale, and disposition
(`actionable`, `not reproduced`, `acceptance recorded` with its authorized
source reference, or `unresolved`, subject to future vocabulary approval).
The assessor cannot accept risk or change authorization. The report also states scope coverage,
unexamined items, evidence freshness, blockers, and whether the assessment is
complete. Do not infer a severity scale or claim repository-wide completeness
from partial evidence.

## Evidence Identity and Freshness

Bind every conclusion to artifact revision, comparison base, target, evidence
source, and capture time. Evidence is usable as current only when it matches
the requested identities and satisfies the source-specific freshness policy.
Do not invent a global TTL. If required freshness rules are undefined, the
source cannot be read, identity differs, or evidence is stale, mark the
finding unknown/stale and stop any current-state conclusion. A new revision
invalidates findings that depend on the old revision.

## Read and Write Permissions

| Operation | Proposed permission |
| --- | --- |
| Read | Requested artifacts and named, necessary evidence sources |
| Return | Report to the requester with evidence identity and limitations |
| Persist | Only to an explicitly specified report destination under separately documented permission |
| Prohibited by default | Edit source, create a branch/PR, post GitHub review or comment, resolve threads, change labels/assignees/issues, approve, merge, release, deploy, or modify authorization |

No finding, score, generated text, or candidate token grants authority.

## State, Failure, Stop, and Resume

| State | Required result |
| --- | --- |
| Ready | Scope, identity, target, read access, and required evidence are unambiguous |
| Assessing | Read only the declared scope; record evidence references and examined coverage |
| Complete | Every in-scope item has a finding or an explicit non-success disposition; currentness is stated |
| Blocked / partial | Record the unmet condition and unexamined scope; do not claim completion |
| Stopped | Honor explicit stop/defer or conflicting instruction; perform no further reads or writes |
| Resumed | Recheck scope, current permissions, artifact identity, target, evidence freshness, and budget before continuing |

Stop on ambiguous scope, unavailable evidence, stale/mismatched identity,
permission change, unsupported write request, conflicting directives, or
exhausted budget. Resume never inherits stale findings as current.

## Future Parser and Behavior Fixture Plan

These are acceptance fixtures for a separately authorized implementation,
not tests run or routing supported by this proposal.

| Case | Expected future behavior |
| --- | --- |
| Standalone, unquoted candidate with explicit scope | Route only if a distinct route is approved and registered |
| Quoted, fenced, bulleted, or embedded candidate text | Do not execute as a directive |
| Candidate combined with another authoritative prefix | Reject as ambiguous; perform no side effect |
| `later`, `read-only`, `no changes`, or stop/defer modifier | Preserve non-executing or stop behavior |
| Request to submit APPROVED review, change a label, or edit source | Block; report cannot perform requested write |
| Missing revision, wrong target, stale evidence, revoked access | Fail closed; report blocker and no current assessment |
| Partial source access or budget exhaustion | Report partial coverage and checkpoint; never report success |

## Distribution, Migration, and Rollout Gates

Before implementation: approve the distinctness decision and exact semantics;
add positive/negative cases to the actual parser suite; define permission
enforcement and evidence vocabulary; map the route in canonical instructions,
skills, workflows, and examples only where required; update downstream
projections and migration guidance; verify that no alias bypasses current
approval or solo-dev rules. If distinctness is not justified, retain existing
routes and do not ship a token. A documentation-only publication has no parser
migration or rollout.

## Proposal Acceptance Criteria

- [x] Inputs, output, evidence identity/freshness, reads, prohibited writes,
  and non-success states are explicit.
- [x] Existing read-only routes and GitHub review submission are distinguished.
- [x] Parser fixtures cover positive, quoted/fenced/bulleted/embedded, dual
  prefix, defer/stop, unauthorized, stale, and partial cases.
- [x] Distribution, migration, and approval gates keep the token unsupported
  until separate authorization.

## References

- PRD:
  [`docs/prd/synthesized/issue-3629-designintent-define-review-completion-and-authorization-cont.prd.md`](../../prd/synthesized/issue-3629-designintent-define-review-completion-and-authorization-cont.prd.md)
- Canonical comparison: [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Shared contract summary: [`docs/reference/intent-work-unit-contracts.md`](../../reference/intent-work-unit-contracts.md#review-assessment)
- Source proposal: #3629
