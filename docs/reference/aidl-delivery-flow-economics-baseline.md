# AIDL Delivery-Flow Economics Baseline

## Scope

Issue: #1753
Domain: AIDL portfolio audit suite, delivery-flow economics
Sprint window: Sprint 38 (Wave 2)

This baseline defines the mandatory economics measures for delivery flow so teams can identify waste and verify improvement over a sprint cycle.

## Baseline and target thresholds

| Metric | Baseline red threshold | Baseline warning threshold | Sprint target |
|---|---|---|---|
| Input tokens per session | >50,000,000 | 15,000,001 to 50,000,000 | <=15,000,000 |
| Session event count | >400 | 151 to 400 | <=150 |
| Input/output ratio | >=300x | 211x to 299x | <=210x |
| Main-session tool calls per phase | >70 | 31 to 70 | <=30 |
| Large pasted context blocks | >=100 KB | 10 KB to 99 KB | <10 KB |
| Re-plan calls per sprint objective | >1 | 1 | 0 to 1 |

## Baseline sampling method

1. Measure at least 5 sessions covering triage, implementation, and merge-wait phases.
2. Capture tokens, events, ratio, and tool-call counts from session telemetry.
3. Label each metric as pass/warn/fail against the threshold table.
4. Store snapshots in the sprint metrics template:
   `docs/templates/aidl-delivery-flow-economics-before-after-metrics-template.md`

## Top waste drivers and actions

| Waste driver | Evidence pattern | Action | Primary owner | Expected impact |
|---|---|---|---|---|
| Context bloat across phase changes | High event count and repeated long prompts | Enforce `/compact` at triage -> implementation -> merge-wait boundaries | Session operator | 35-50% token reduction |
| Repeated re-planning loops | Multiple "plan next sprint" runs for same objective | Reuse one canonical sprint template with delta-only updates | Sprint planner | 40-60% fewer planning tokens |
| Main-thread orchestration overload | 70+ tool calls in a phase | Delegate scan/research to background agents and keep main thread decision-only | Orchestrator | 40-60% event reduction |
| Large payload pastes | 100 KB+ message payloads | Use file references instead of pasted blocks | All contributors | Prevents recurring context replay cost |
| Non-optimized model routing on routine work | High-cost model usage on low-complexity tasks | Default routine loops to lighter models; upshift only on explicit triggers | Agent owner | 5-10% incremental savings |

## Sprint-cycle tracking expectation

Improvements are only counted when a metric is tracked at:

1. Sprint start baseline (Day 1-2)
2. Mid-sprint checkpoint (Day 5-7)
3. Sprint closeout (Day 10-14)

A metric is considered improved for the cycle when the closeout value is better than baseline and meets the sprint target or shows >=15% improvement toward target.
