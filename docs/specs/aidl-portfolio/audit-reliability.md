# AIDL Portfolio Reliability Audit

## Objective

Define reliability audit criteria for incident routing quality and end-to-end linkage across incident, remediation, and verification artifacts.

## Incident-to-Backlog Routing Contract

Every production-impacting incident must route to actionable backlog work.

| Requirement | Validation rule |
|---|---|
| Incident classification | Severity and impact field populated |
| Ownership | DRI assigned at incident open time |
| Backlog linkage | At least one remediation issue or PR linked |
| Priority mapping | Remediation priority aligns with incident severity |
| Closeout evidence | Verification artifact linked before closure |

## Field Quality Requirements

Audit checks enforce consistent reliability metadata.

| Field | Quality rule |
|---|---|
| Incident ID | Unique and immutable |
| Service/area | Matches portfolio area taxonomy |
| Customer impact | Explicit impact statement |
| Detection timestamp | Present and chronologically valid |
| Mitigation timestamp | Present for mitigated incidents |
| Root-cause summary | Required for high and critical incidents |
| Verification link | Required for closure |

## Incident to Remediation to Verification Linkage

Reliability quality requires a complete chain:

1. Incident record captures impact and owner.
2. Remediation issue or PR references incident ID.
3. Verification artifact confirms fix behavior.
4. Incident closure references verification artifact.

Missing links in the chain produce warn or fail outcomes depending on severity.

## Scoring and Thresholds

| Metric | Target | Status threshold |
|---|---|---|
| Routed incidents with remediation link | 100% | Warn <100%, Fail <95% |
| Verified closures | 100% for high/critical | Warn <100%, Fail <98% |
| Median incident-to-remediation creation latency | <= 1 business day | Warn >1 day, Fail >2 days |
| Repeat incidents without prior verification | 0 | Warn >0, Fail >=2 |

## Reliability Audit Outputs

1. Coverage report of linked vs unlinked incidents.
2. Latency table by severity and area.
3. Repeat-incident list with missing verification context.
4. Remediation backlog recommendations with priority alignment.
