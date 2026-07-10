# AIDL Portfolio Audit Framework

## Objective

Define the audit suite structure, scoring rubric, evidence model, and operating cadence used to evaluate portfolio-management quality and conformance.

## Audit Domains

| Domain | Scope | Primary signals |
|---|---|---|
| Architecture conformance | Lifecycle model, control-point alignment, field consistency | Drift count, control coverage |
| Governance and exceptions | Policy gates, waiver hygiene, ownership quality | Waiver expiry compliance, unresolved exceptions |
| Reliability and SRE linkage | Incident routing and remediation quality | Incident-to-remediation latency, verification closure |
| Learning and memory | Pattern extraction and promotion quality | Promotion acceptance rate, downstream reuse |
| Delivery-flow quality | PR lifecycle execution and release readiness | Merge-readiness compliance, blocked-to-resolved ratio |

## Scoring Rubric

Each domain receives a status outcome plus a normalized maturity score.

| Status | Rule | Maturity score band |
|---|---|---|
| Pass | All required controls satisfied with complete evidence | 85-100 |
| Warn | Non-blocking control drift or incomplete non-critical evidence | 60-84 |
| Fail | Blocking control missing, stale, or contradicted by evidence | 0-59 |

### Composite scoring

1. Compute a 0-100 score per domain.
2. Apply portfolio weighting:
   - Governance and exceptions: 25%
   - Reliability and SRE linkage: 25%
   - Architecture conformance: 20%
   - Learning and memory: 15%
   - Delivery-flow quality: 15%
3. Derive final maturity tier:
   - Tier 4 (Optimized): 90+
   - Tier 3 (Managed): 75-89
   - Tier 2 (Defined): 60-74
   - Tier 1 (Reactive): <60

## Evidence Model

Required evidence must be linkable to immutable GitHub artifacts.

| Evidence type | Required fields |
|---|---|
| Policy gate result | Control ID, status, timestamp, source workflow URL |
| Exception or waiver record | Reason, owner, approval reference, expiry date |
| Incident linkage | Incident ID, remediation issue/PR, verification artifact |
| Learning promotion decision | Candidate ID, decision, reviewer, downstream adoption references |

Evidence quality gates:

1. No orphaned records without source URL.
2. No waived controls without expiry metadata.
3. No pass outcomes when mandatory evidence is absent.

## Cadence and Operating Rhythm

| Audit run | Frequency | Outcome |
|---|---|---|
| Lightweight health sweep | Daily | Drift and exception delta report |
| Full domain audit | Weekly | Domain scorecards and remediation issue set |
| Sprint closeout audit | End of sprint | Closeout quality package for sprint issue |
| Quarterly calibration | Quarterly | Rubric tuning and threshold adjustment |

## Output Contract

1. Domain scorecard with pass/warn/fail and maturity score.
2. Prioritized findings list with owner and due date.
3. Exception and waiver ledger with expiry risk highlights.
4. Remediation backlog payloads ready for issue creation.
