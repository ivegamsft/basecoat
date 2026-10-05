# Spec: Merge-group readiness

## Scope

This prerequisite only adds merge-group execution for the existing CI, Agent Merge
guardrails, and PR Validation workflows, replacing the release-label job with a
tested implementation that handles pull-request, manual-dispatch, and merge-group
events. It makes no queue configuration or policy-posture change.

## Contract

- Read `base_ref`, `base_sha`, and `head_sha` from the merge-group event; normalize
  `refs/heads/<branch>` to the branch name.
- Compare the merge-group base and head and reject an invalid or partial commit range.
- Resolve open PRs targeting that base whose current head SHA is in the range.
- Fail if no current constituent can be resolved; never return success for an
  unresolved merge-group event.
- Re-fetch every selected PR and require it to remain open, target the same base,
  and retain the head SHA present in the merge-group range.
- Apply the existing release-label formats and explicit exemptions separately to
  each current PR.
- Keep standard pull-request label polling and manual branch-to-PR lookup behavior.

## Verification

`node --test tests/merge-group-release-label-tests.cjs` covers label formats,
per-PR exemptions, current-head selection, duplicate/missing membership, and
workflow trigger wiring. The standard repository test suite invokes the same tests.

## Deferred queue setup

A later, separately authorized layer may configure a repository-scoped native queue
only after these checks are present on `main` and observed on generated merge-group
commits. No ruleset, auto-merge posture, approval boundary, or live setting is
changed by this spec.
