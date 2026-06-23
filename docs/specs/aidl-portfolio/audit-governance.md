# AIDL Portfolio Audit Governance

## Objective

Define policy enforcement expectations, exception-record requirements, and waiver hygiene controls for portfolio audit operations.

## Policy Gate Coverage

The governance audit validates that high-impact lifecycle transitions are policy-gated.

| Lifecycle transition | Required gate |
|---|---|
| Backlog to Ready | Scope quality and owner assignment |
| In Progress to In Review | Evidence and test-intent completeness |
| In Review to Release Ready | Required checks and guardrail evaluation |
| Release Ready to Done | Post-merge evidence and rollback reference |
| Incident closure | Remediation and verification linkage |

## Exception Record Contract

All exceptions must be represented as structured records.

| Field | Requirement |
|---|---|
| Exception ID | Unique identifier |
| Control reference | Policy or gate being bypassed |
| Reason | Specific and auditable business/technical rationale |
| Owner | Accountable approver |
| Created date | Timestamp of approval |
| Expiry date | Mandatory for temporary exceptions |
| Exit condition | Measurable condition to remove exception |
| Evidence link | URL to approval artifact and follow-up work |

## Waiver Handling Model

| Waiver state | Entry criteria | Exit criteria |
|---|---|---|
| Draft | Candidate exception submitted | Approved or rejected |
| Active | Approved with owner and expiry | Closed by remediation or expiry |
| Expired | Current date exceeds expiry | Escalated to blocking status |
| Closed | Control compliance restored | Archived with closure evidence |

Waiver guardrails:

1. Active waivers must have explicit expiry.
2. Expired waivers automatically escalate to block.
3. Renewals require fresh rationale and re-approval evidence.

## Governance Audit Checks

1. Policy gates exist and are active for all required transitions.
2. Exceptions are complete and traceable to approvers.
3. Waiver expiries are monitored and acted on before breach.
4. Duplicate or stale exceptions are consolidated or closed.
5. Governance findings are mapped to owners and due dates.

## Escalation Rules

| Severity | Trigger | Required response |
|---|---|---|
| Critical | Missing release-blocking gate or expired waiver on active work | Immediate blocking issue and owner notification |
| High | Exception without owner/expiry or repeat waiver abuse | Escalation issue within sprint |
| Medium | Incomplete metadata or delayed closure evidence | Add remediation task to sprint backlog |
