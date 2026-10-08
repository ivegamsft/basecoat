---
issue: 3595
title: "fix(release): align PR label exemptions with release coverage policy"
status: reviewed
author: ibuyspy
created: 2026-10-06
labels: ["bug", "priority:medium", "needs-triage", "needs-prd", "needs-info", "synthesize-spec"]
---

# PRD: fix(release): align PR label exemptions with release coverage policy

## Problem Statement

A PR can satisfy the release-label gate yet count as unlabeled in the tag release workflow.

The merge gate accepts release labels, `dependencies`, and
`skip-release-label-gate`; tag coverage currently recognizes release labels
only. The disagreement turns accepted dependency/documentation work into a
surprise release failure.

## Scope

Define one classification reused at PR, exact merge-group, and release-window
validation. Preserve existing exemptions and the existing release-window
tolerance: at most 10% genuinely uncovered PRs, with integer arithmetic.
An exemption means covered for this label policy, not permission to bypass
authorization, tests, release scope, version consistency, or publication gates.

Do not change the approved release scope, add new exemptions, relabel historical
PRs automatically, or treat a date-limited/truncated query as a complete window.

## User Outcomes

Maintainers see the same covered/uncovered classification before merge and
release. Evidence lists covered-by-release-label, covered-by-exemption, and
uncovered PRs separately; an exempt item is not described as sprint work.
Missing inventory or label evidence is an error, not zero uncovered work.

## Success Criteria

- [ ] All three stages reuse the same classifier and reason codes.
- [ ] Supported exemptions cannot unexpectedly become uncovered at release.
- [ ] Exactly 10% passes with a warning; above 10% fails.
- [ ] Complete immutable release-window evidence and malformed-input failures are tested.
- [ ] Existing authorization, native queue and release gates remain unchanged.
- [ ] #3595 stays open until implementation and stage verification pass.

## References

- Refs #3595
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3595>
