# PRD: Merge-group readiness for native queue checks

## Status

Draft prerequisite layer for issue #3499. This scope prepares required workflows to
report checks on GitHub merge-group commits; it does not configure or activate a queue.

## Problem

CI, agent-merge guardrails, and release-label validation must run on synthetic
merge-group commits before a native queue can safely require their check contexts.
Release-label validation must identify and recheck every current constituent PR,
not silently skip validation when the event does not contain a pull-request object.

## Outcome

Add `merge_group` triggers to CI, Agent Merge, and PR Validation. Validate each
current main-targeting PR head found in the merge-group commit range against its
release-label contract, re-fetch each selected PR before accepting its labels, and
fail closed when membership cannot be resolved or has changed.

## Out of scope

- Changing solo-dev queue posture or auto-merge behavior.
- Creating, applying, or activating repository/organization rulesets.
- Changing approval, production-release, or deployment gates.
- Claiming that a draft PR or readiness check is authorization to merge or release.

## Acceptance criteria

1. The three named workflows trigger for `merge_group.checks_requested`.
2. Merge-group release-label validation uses current PR heads and current labels.
3. Missing, stale, ambiguous, or unlabeled membership fails the check.
4. Existing PR label formats, exemptions, and manual dispatch behavior remain intact.
5. Focused regression tests cover positive and fail-closed paths.
