## Gate Validation Checklist

Use this checklist before moving stage state forward.

### Gate 1: Mining completeness

- [ ] Required evidence sources are present.
- [ ] `A1-source-index` exists and includes provenance plus timestamps.
- [ ] `A2-pattern-candidates` exists and every candidate links to source evidence.

### Gate 2: Raw log integrity

- [ ] `B1-raw-findings-log` is append-only.
- [ ] No entries were pruned or merged pre-triage.
- [ ] Duplicate and conflicting findings are retained.

### Gate 3: Triage quality

- [ ] All findings classified as common, repo-specific, or unknown.
- [ ] `C1-triage-matrix` is complete.
- [ ] `C2-classification-rationale` includes evidence-backed rationale.
- [ ] Unknown findings include explicit follow-up questions.

### Gate 4: Plan readiness

- [ ] `D1-enhancement-backlog` has prioritized, actionable items.
- [ ] Every plan item has expected signal and validation method.
- [ ] `D2-early-detection-gates` includes trigger, owner, and expected action.
- [ ] High-risk pattern classes have at least one early-detection gate.

