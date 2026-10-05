# PRD: Review Activation Boundaries

## Problem and Scope

Issue #3333 records overlapping frontend review triggers and complementary
security agent/skill roles without explicit ownership. No live misrouting is
claimed. The current user directive authorizes this scoped upstream repair.

## Requirements and Success Criteria

1. Findings-only frontend implementation review selects `frontend-audit`;
   implementation and remediation select `frontend-dev`.
2. Journey, wireframe, and experience assessment select `ux`.
3. The security agent coordinates SOC work; its namesake skill implements rules
   and automation. Neither role authorizes live actions.
4. Explicitly requested composition remains supported, with review before fixes.
5. Every changed asset has neighboring positive/negative evaluation cases.

## Non-Goals and Rollout

No model, tool, runtime router, consumer-owned asset, or live environment changes.
Distribute through the normal BaseCoat refresh path after merge; rollback by
reverting this change. Activation wording is a contract, not proof of host
selection behavior.

## References

- [Technical spec](../spec/review-activation-boundaries.spec.md)
- Tracking: #3333; parent: #3324
