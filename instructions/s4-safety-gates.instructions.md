---
description: "Use when defining S4 cutover safety gates, including shadow-mode validation, rollback testing, and on-call review."
applyTo: ".github/**/*"
---

# S4 Safety Gates

Use this instruction for S4 deployment guardrails and readiness checks.

## Expectations

- Require shadow-mode validation before any production cutover.
- Define circuit breaker thresholds explicitly, including error rate and latency conditions.
- Verify rollback is testable, not just documented.
- Make on-call review a required step before 100% cutover.

## Validation Rules

- Capture the exact failure condition that blocks cutover.
- Distinguish validation failure from a transient environment issue.
- Record whether the failure should trigger fix-forward, delay, or rollback.
- Keep the decision criteria visible to everyone making the release call.

## Review Lens

- Are the gate thresholds clear enough to execute without interpretation?
- Is there a tested rollback path if the gate fails?
- Does the cutover plan state who must approve the final move to 100%?
