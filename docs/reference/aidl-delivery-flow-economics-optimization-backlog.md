# AIDL Delivery-Flow Economics Optimization Backlog

## Purpose

Prioritized backlog structure for converting delivery-flow economics findings into sprint-executable work.

## Prioritization model

Score each candidate with:

- **Impact (1-5)**: expected token/event reduction and cycle-time gain
- **Effort (1-5)**: implementation complexity and operational overhead
- **Risk (1-5)**: chance of disruption or rollback
- **Urgency (1-5)**: severity against baseline thresholds

Priority score:

`(Impact * Urgency) - (Effort + Risk)`

Higher score means earlier execution.

## Backlog lanes

| Lane | Time horizon | Typical changes |
|---|---|---|
| L1: Quick wins | Current sprint | Prompt hygiene, compaction policy, delta-only updates |
| L2: Structural | Next 1-2 sprints | Delegation patterns, workflow refactors, guardrail tuning |
| L3: Platform | 2+ sprints | Telemetry automation, policy-as-code enforcement, default routing updates |

## Initial prioritized backlog for #1753

| ID | Title | Lane | Impact | Effort | Risk | Urgency | Score | Acceptance check |
|---|---|---|---:|---:|---:|---:|---:|---|
| DFE-01 | Enforce phase-boundary compaction policy | L1 | 5 | 2 | 1 | 5 | 22 | >=90% sessions show triage->impl and impl->merge compaction |
| DFE-02 | Replace pasted blocks with file-reference-only guidance | L1 | 5 | 1 | 1 | 4 | 18 | Largest pasted context block remains <10 KB across sprint sample |
| DFE-03 | Shift scan-heavy work to background delegation | L2 | 4 | 3 | 2 | 4 | 11 | Main-session tool calls <=30 per phase median |
| DFE-04 | Reuse sprint template and delta prompts | L2 | 4 | 2 | 1 | 3 | 9 | Re-plan count <=1 per sprint objective |
| DFE-05 | Apply routine-loop model routing defaults | L3 | 3 | 2 | 2 | 2 | 2 | Routine tasks routed to low-cost models unless upshift trigger fires |

## Ownership and cadence

| Activity | Owner | Cadence |
|---|---|---|
| Baseline capture | `copilot-usage-analytics` | Sprint start |
| Waste-driver audit | `flow-audit` + `flow-auditor` | Weekly |
| Optimization plan refresh | `flow-optimize` + `flow-optimizer` | Mid-sprint |
| Burndown tracking | `backlog-burndown` | 2-3 times per week |
| Closeout comparison | Delivery lead | Sprint end |

## Operating flow

1. Capture baseline and mark pass/warn/fail against `aidl-delivery-flow-economics-baseline.md`.
2. Rank candidates using the priority score.
3. Open or update issues with `DFE-*` IDs and owner assignments.
4. Track movement using the before/after template:
   `docs/templates/aidl-delivery-flow-economics-before-after-metrics-template.md`.
5. Close completed items only when closeout metrics show improvement.
