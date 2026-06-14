---
description: "Sprint closeout protocol for label hygiene, carryover tracking, and planning handoff"
applyTo: ".github/**/*,docs/**/*,agents/**/*"
---

# Sprint Closeout Auditor Protocol

Use this guidance when closing a sprint and preparing the next planning cycle.

## Label Enforcement During Sprint

Apply sprint and wave labels during active delivery, not only at closeout:

1. Apply `sprint:*` and `wave:*` labels during issue intake and PR review.
2. Reject closeout checklists that require label backfill.
3. If unlabeled work is found, create a corrective issue and capture owner/date.

## Error and Failure Triage

Treat unresolved failures as explicit closeout outcomes:

1. Classify each failure as `critical`, `high`, `medium`, or `low`.
2. Escalate `critical` and `high` failures to a tracked GitHub issue before signoff.
3. Record affected workflow/run links and expected resolution window.

## Two-Phase Checklist

Separate sprint closeout from release-readiness to avoid mixed concerns:

### Phase 1: Sprint Closeout

1. Scope complete (merged or formally deferred)
2. CI status verified for sprint work
3. Open defects triaged
4. Carryover created as issues
5. Closeout decision documented

### Phase 2: Release Readiness

1. Release blockers reviewed
2. Deployment gates validated
3. Production-specific risks tracked

Do not block sprint closure on non-sprint release tasks; track them in release workflows.

## Carryover Management

Carryover items must be first-class artifacts:

1. Convert every unresolved action into a GitHub issue.
2. Include owner, due date, sprint target, and dependency references.
3. Link each carryover issue from the closeout report.
4. Avoid prose-only "action needed" items.

## Handoff to Sprint Planning

Produce a structured handoff consumed by sprint planning:

1. Completed scope summary
2. Carryover issue list
3. Failure and risk summary
4. Recommended ordering for oldest-first backlog execution

Reference `docs/templates/sprint-structure.md` and provide deltas instead of full backlog restatement.
