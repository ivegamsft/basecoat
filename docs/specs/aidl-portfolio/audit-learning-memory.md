# AIDL Portfolio Learning and Memory Audit

## Objective

Define audit expectations for extracting high-value patterns, making promotion decisions, and validating downstream adoption of promoted knowledge.

## Candidate Extraction

Pattern candidates are harvested from completed delivery, incidents, and retrospectives.

| Source | Candidate criteria |
|---|---|
| Sprint closeout evidence | Repeated blocker or mitigation pattern |
| Incident postmortem | Verified corrective action with reusable steps |
| PR lifecycle outcomes | Repeatable quality-gate or workflow improvement |
| Governance findings | Policy improvement with broad applicability |

Extraction quality checks:

1. Candidate has a clear problem-pattern-outcome statement.
2. Candidate cites source artifacts.
3. Candidate includes expected reuse context.

## Promotion Decision Model

| Decision | Entry criteria | Required metadata |
|---|---|---|
| Promote | High confidence reuse value and validated evidence | Approver, rationale, target asset path |
| Hold | Useful but insufficient confidence or scope clarity | Missing evidence note and re-review date |
| Reject | Not reusable or contradicted by evidence | Rejection rationale and source links |

## Downstream Adoption Audit

Promoted patterns must demonstrate real usage, not just publication.

| Adoption signal | Validation rule |
|---|---|
| Reference in new specs or guides | At least one linked consumer artifact |
| Process uptake | Observed usage in sprint or PR workflows |
| Outcome impact | Improvement metric tied to promoted pattern |
| Retirement hygiene | Stale patterns are deprecated with replacement links |

## Scoring

| Dimension | Pass | Warn | Fail |
|---|---|---|---|
| Candidate quality | >= 95% complete metadata | 80-94% complete metadata | <80% complete metadata |
| Promotion discipline | Decisions include rationale and owner | Occasional missing rationale | Frequent missing rationale/owner |
| Adoption validation | >= 80% promoted items show adoption evidence | 50-79% adoption evidence | <50% adoption evidence |
| Memory hygiene | No stale unreviewed items beyond SLA | Limited stale items within one cycle | Chronic stale backlog beyond SLA |

## Audit Outputs

1. Candidate pipeline summary (new, promoted, held, rejected).
2. Promotion decision ledger with rationale quality score.
3. Adoption trace report linking promoted patterns to consumers.
4. Cleanup queue for stale or low-value memory entries.
