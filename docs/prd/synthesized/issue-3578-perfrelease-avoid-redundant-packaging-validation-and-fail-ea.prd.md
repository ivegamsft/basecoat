---
issue: 3578
title: "perf(release): avoid redundant packaging validation and fail early on known errors"
status: ready-for-review
author: copilot
created: 2026-10-06
labels: ["enhancement", "priority:medium"]
---

# PRD: perf(release): avoid redundant packaging validation and fail early on known errors

## Problem Statement

Post-merge release-chain runs dispatch `package-basecoat.yml` on the moving
`main` ref. The packaging workflow independently runs the full validator and
can cancel an earlier run because its concurrency key is ref-based. This can
validate a different commit than the merge that caused the release decision,
drop distinct target requests, and spend runner time on work that should stop
after a syntax failure.

Read-only audit window: 2026-10-04T14:41:06Z through 2026-10-06T14:41:06Z.
Inventory: 5,761 unique workflow runs; job timing sample: 98 runs. There were
43 package runs (11 success, 18 failure, 14 cancelled; 41 workflow_dispatch).
The counts do not establish that all runs were duplicate packaging requests.

## Description

Bind the post-merge release decision, validation, and package artifact to the
merged commit SHA and its tree. Reject an unavailable merge SHA rather than
falling back to a PR-head or current-main ref. Reuse the syntax-first validation
gate already required by #3603, and report target or validation failures
explicitly.

Coalesce a new request into a queued or running package request only when its
exact immutable target SHA matches. Key concurrency by that SHA and do not
cancel active runs; different commit SHAs remain independent. A later request
with no matching active run receives fresh validation.

## Intake Contract

### Why This Matters

An early syntax failure was observed in about one minute while Windows
validation continued for about 14 minutes (run 37476844263). Concurrent merges
also exposed a mutable-ref and cancellation hazard. Immutable source identity
and syntax-first job dependencies prevent these failures without assuming
distinct merges share the same source tree.

### Scope

- Pass the merged commit SHA from post-merge release chaining to package
  workflow dispatch and to the release gate's source identity.
- Resolve and verify the SHA and tree before validation, check out that exact
  SHA in all reusable validation jobs, and package only after SHA/tree
  comparisons succeed.
- Keep expensive validation dependent on `validate-workflow-syntax`.
- Coalesce matching queued/in-progress dispatch requests; do not cancel
  different targets.
- Keep the post-merge release gate explicitly `dry_run=true`. Its dispatch
  marker is neither production authorization nor validation evidence.
- Keep automatic tag creation/ownership out of scope (#3594).

### Success Criteria

- A moved `main` ref cannot change the SHA/tree validated or packaged for an
  earlier merge.
- Missing or malformed merge targets fail explicitly before release-gate and
  packaging dispatch.
- A syntax failure prevents Unix/Windows validation and package jobs from
  proceeding.
- Active equivalent SHA requests coalesce; distinct SHA requests retain
  separate run names and concurrency groups.
- No PR-head, dry-run, stale, or untrusted evidence is treated as a successful
  validation result.
- Existing tag-triggered packaging, release authorization, and tag ownership
  behavior remain unchanged.

## References

- Spec: `docs/spec/synthesized/issue-3578-perfrelease-avoid-redundant-packaging-validation-and-fail-ea.spec.md`
- Source issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3578>
- Syntax gate: <https://github.com/IBuySpy-Shared/basecoat/pull/3603>
- Tag ownership remains separate: <https://github.com/IBuySpy-Shared/basecoat/issues/3594>
