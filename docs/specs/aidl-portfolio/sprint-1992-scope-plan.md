# Sprint 1 Scope Plan for #1992

## Context

- **Sprint issue:** #1992
- **Parent control-plane issue:** #1991
- **Intent:** `ship-it`
- **Planning objective:** decompose Sprint 1 into execution waves with clear acceptance gates

## Wave Decomposition

### Wave 1 - foundations/docs/guards

**Issues:** #1739, #1741, #1747, #1748, #1824, #1826

**Acceptance criteria:**

1. A baseline governance model decision is recorded for downstream enforcement (#1826).
2. Operator documentation and guardrail visibility guidance are captured for execution teams (#1739).
3. Bootstrap and conformance/security baselines are specified so Wave 2 implementations can be validated against them (#1741, #1747, #1748).
4. Merge-governance alignment expectations are explicitly documented for live policy behavior (#1824).

### Wave 2 - core implementations

**Issues:** #1740, #1743, #1744, #1746, #1753, #1755

**Acceptance criteria:**

1. Core pipelines and routing implementations are decomposed into execution-ready units with clear dependencies (#1740, #1743, #1746).
2. Portfolio rollup and economics outputs have defined input/output contracts and evidence expectations (#1744, #1753).
3. PR lifecycle routing and closeout guardrails coverage is defined for validation and release-readiness checks (#1755).
4. Implementation sequence is blocked until Wave 1 governance and control-baseline criteria are met.

### Wave 3 - cleanup/policy/handoff

**Issues:** #1745, #1827

**Acceptance criteria:**

1. Routing/naming normalization cleanup scope is explicitly tied to post-implementation hardening outcomes (#1745).
2. Fleet adoption learnings and downstream handoff/scorecard expectations are defined for operational continuity (#1827).
3. Remaining follow-up work is captured as handoff items if not completed in Sprint 1.

## Out of Scope and Deferred Notes

- No issues from the required #1992 decomposition set are removed from Sprint 1 planning scope.
- If Wave 2 execution starts without a resolved governance decision in #1826, implementation kickoff is deferred until that decision is made.
- Any residual cleanup beyond #1745 and #1827 is deferred to the next sprint as explicit carryover items.

## Remaining Planning Blockers

| Blocker | Impact | Mitigation |
|---|---|---|
| #1826 governance model decision still open | Prevents enforcement finalization and can delay Wave 2 start | Resolve #1826 during Wave 1 before implementation PR slicing |
| All scoped child issues remain open | No implementation closeout evidence yet | Execute wave-by-wave PR plan under serialized merge hold |
