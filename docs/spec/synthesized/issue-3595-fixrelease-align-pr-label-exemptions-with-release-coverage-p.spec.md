---
issue: 3595
title: "fix(release): align PR label exemptions with release coverage policy"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["bug", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# Spec: fix(release): align PR label exemptions with release coverage policy

## Problem Statement

A PR can satisfy the release-label gate yet count as unlabeled in the tag release workflow.

## Design and Interfaces

Extract/reuse the trusted classifier in `scripts/merge-group-release-labels.cjs`
and its distributed runtime counterpart. Preserve the existing supported
case-insensitive release labels (`wave:`, `sprint:`, `wave-`, `sprint-` with a
nonempty suffix, or exact `wave/sprint`) and exact exemptions
`skip-release-label-gate` and `dependencies`. No title, author, fork status,
body text, or issue label is an implicit exemption.

Return a typed result with `covered`, a stable reason code
(`release-label`, `explicit-exemption`, `dependency-exemption`, `uncovered`),
and the matched label when applicable. Release-label classification wins when
several supported labels coexist. Keep a compatible wrapper for existing
`evaluatePullRequestLabels` callers; do not silently alter their output shape.

Require label evidence to be an array of nonempty strings or objects with a
nonempty string `name`. Reject malformed PR numbers, duplicate PR records, and
incomplete label data explicitly. An empty, valid label array is uncovered.
Classify fork PRs identically; classification grants no fork-code trust.

## Stage Contracts

The PR gate and exact merge-group gate require each member to be covered.
The release gate uses that same per-PR classification, retaining its existing
aggregate tolerance: `uncovered_count * 100 <= total_count * 10`.
Exempt PRs stay in the denominator and count as covered; do not omit them to
change the ratio. Exactly 10% emits a partial-coverage warning; above 10% fails.
All-covered windows pass without that warning.

An empty complete window reports no releasable PR evidence explicitly; the
coverage classifier does not authorize publication. Existing no-release and
release-scope checks still decide whether publication is allowed.

For each stage, emit total, release-label-covered, exempt-covered, uncovered,
and bounded PR-number/reason lists. Preserve full machine-readable inventory;
human log truncation must not truncate evaluation.

## Release Inventory and Trust

Resolve the requested tag and previous eligible SemVer tag to immutable commit
SHAs using the existing release scope/version contract. Require the prior tag
to be an ancestor; do not choose a prior tag only by mutable creation date.
Use complete paginated merged-PR membership associated with commits in that
exact range, reconcile merge identities, and deduplicate by repository/PR.
Date search may help discovery but is not authoritative membership.
If the existing collector cannot prove complete membership, stop before
publication and report the missing evidence; never accept the first 500 hits.

Read labels live immediately before the gate, record the evaluation snapshot,
and revalidate it at the publication boundary. A changed label or scope requires
a new evaluation. Use trusted base/release code; PR labels are data and cannot
load or replace policy code. This change must not expand token permissions.

## Implementation and Testing

Wire the helper into PR validation, `merge-group-release-labels` and `release.yml`,
including distributed workflow/runtime copies and bound digests where required.
Replace the release-only jq regex rather than adding a second policy.

Fixtures cover all supported aliases/case variants, supported exemptions,
mixed labels, fork PRs, empty arrays, malformed data, duplicate inventory,
exactly 1/10 and 2/10 uncovered, all-covered and complete empty windows.
Test pagination beyond 500 records, ancestry/membership failure, inaccessible
PRs, changed labels and immutable tag selection. Assert equal per-PR results
across all three actual workflow entry points.

## Failure, Rollout and Observability

API failures, unknown membership and malformed labels fail closed with an
actionable diagnostic. Do not substitute a zero-count window or suppress
coverage failures. Retry only existing bounded transient API errors.
Deploy through normal PR checks/native queue; exercise real current-head and
merge-group classification, then run a read-only exact-range release preview.
Do not create a test tag or publish solely to test labels.

Record scope SHAs, classifier version, inventory completeness and reason counts.
Rollback restores the prior workflows/helper together; existing labels and
release artifacts are not rewritten. Risks are stale labels, scope collector
ambiguity and accidental threshold changes; the corresponding failure fixtures
must pass before rollout.

## Acceptance Criteria

- [ ] One classifier governs all stages without changing other authorization.
- [ ] Exact thresholds and every existing exemption pass cross-stage fixtures.
- [ ] Complete immutable release inventory and label revalidation are verified.
- [ ] Source/runtime copies and bound digests are consistent.
- [ ] Implementation evidence includes exact commands and actual outcomes.
- [ ] This specification PR does not close #3595 or claim runtime delivery.

## References

- PRD: `docs/prd/synthesized/issue-3595-fixrelease-align-pr-label-exemptions-with-release-coverage-p.prd.md`
- Refs #3595
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3595>
