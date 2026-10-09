---
issue: 3629
title: "design(intent): define review: completion and authorization contract"
status: proposal
author: ibuyspy
created: 2026-10-07
---

# PRD: design(intent): define review: completion and authorization contract

## Proposal Status

This is a documentation proposal only. `review:` is not registered or
supported syntax. No runtime, parser, workflow, approval, or issue-metadata
change is authorized. The proposal is ready for design review, not
implementation.

## Problem Statement

BaseCoat needs an unambiguous way to distinguish read-only assessment from
implementation, GitHub review submission, authorization, and post-delivery
learning. Existing `audit:`, `investigate:`, and `rca:` already cover
read-only assessment or diagnosis. A new `review:` alias could duplicate those
routes or be mistaken for submitting an APPROVED review.

## Why This Matters

Assessment must identify exactly what was examined and how current its
evidence is, without acquiring authority to change the inspected artifact or
its authorization. A report based on the wrong revision or target is not
reliable evidence.

## Scope

In scope: compare the candidate with existing read-only routes; define bounded
inputs, outputs, evidence identity and freshness, permitted effects, stop and
resume behavior, future parser fixtures, and adoption gates.

Out of scope: registering a prefix or alias; changing routing; writing code,
editing the inspected source, posting PR reviews or comments, resolving
threads, changing labels, assignments, issue or PR state, approving work, or
altering solo-dev review policy.

## Alternatives and Recommendation

| Alternative | Benefit | Cost / risk |
| --- | --- | --- |
| Keep `audit:` / `investigate:` / `rca:` and clarify their boundaries | Reuses supported, read-only routes | May require better examples for artifact-focused assessment |
| Add `review:` as an alias | Familiar wording | Adds no distinct outcome and can be confused with GitHub review submission |
| Add `review:` only for a demonstrably distinct report contract | Could make a unique artifact-assessment task discoverable | Requires evidence of a distinct input/output contract and an explicit implementation decision |

Recommendation: retain the existing read-only routes. Consider a distinct
`review:` route only if a consumer need cannot be expressed by those routes
and the proposed input, output, lifecycle, and ownership are materially
different. Do not add a synonym for discoverability alone.

## Bounded Proposal Contract

If separately approved for implementation, an assessment would accept an
explicit scope and immutable identity for every inspected artifact:
repository or system, artifact path or identifier, revision/content digest
where available, comparison base, target, and evidence capture time. Its
output would be a finding report with finding identifier, affected
artifact/revision, severity, confidence, evidence references, rationale, and
a disposition or explicit unresolved state. Severity and confidence scales
must be selected and documented before implementation; this proposal does
not prescribe a repository-wide scale.

Evidence is current only for the exact artifact, comparison base, and target
identified in the request, and only within a freshness policy defined by the
evidence source. Record capture time and source identity. If identity is
missing, evidence cannot be refreshed, a freshness policy is absent where
needed, or the target/revision changed, report unknown or stale evidence and
stop short of a current assessment. Never imply a universal time-to-live.

The operation is read-only. It may read only the requested artifacts and
necessary, explicitly identified evidence sources. It must not write to the
subject, GitHub reviews/comments, labels, assignments, issue or PR state, or
authorization records. A report may be returned to the requester; persistence
requires a separately specified destination and permission.

## Failure, Stop, and Resume

Stop and report a blocker on ambiguous scope, inaccessible evidence,
unmatched revision/target, stale or revoked evidence, conflicting directives,
or a request that requires a write. A partial report must identify examined
and unexamined scope and must not claim completion. Resume from the recorded
scope and evidence references only after rechecking current artifact identity,
target, permissions, and freshness. A changed revision invalidates affected
findings and requires reassessment; prior output is not approval.

## Proposal Acceptance Criteria

- [x] Alternatives and overlap with `audit:`, `investigate:`, `rca:`, and
  GitHub review submission are explicit; the recommendation avoids an
  unjustified alias.
- [x] Scope, non-goals, input/output, evidence identity and freshness,
  read-only permissions, failure, stop, and resume boundaries are specified.
- [x] Future positive and negative parser fixtures and distribution/migration
  gates are listed without claiming they are implemented.
- [x] Proposal status and the unsupported-token boundary are explicit.

## Future Adoption and Rollout Gates

Any adoption requires a separately approved implementation issue and spec;
evidence that existing routes are insufficient; an explicitly chosen
severity/confidence vocabulary; actual-parser tests; documented read/write
behavior; and review of authorization and distribution effects. Update the
canonical intent guide, relevant instructions and skills, downstream
projections, examples, and migration notes together. Until those gates pass,
keep the candidate absent from routing and treat this document as design
input only. Existing solo-dev review and authorization policy remains
unchanged.

## References

- Source proposal: #3629
- Comparison and supported-versus-proposed vocabulary:
  [`docs/design/ai-sdlc-work-units.md`](../../design/ai-sdlc-work-units.md)
- Current prefix routing:
  [`docs/guides/intent-prefixes.md`](../../guides/intent-prefixes.md)
