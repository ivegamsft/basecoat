# Policy-as-Code Compliance — Detail Reference

## Policy Metadata Requirements

Every policy must include:

| Field | Requirement |
|---|---|
| `policy_id` | Stable unique identifier used across reports and audits |
| `title` | Short control name |
| `severity` | `critical`, `high`, `medium`, or `low` |
| `owner` | Team or role accountable for the control |
| `frameworks` | Mappings: `SOC2 CC6.1`, `HIPAA 164.312`, `GDPR Art. 32`, `FedRAMP AC-2` |
| `remediation` | Specific fix guidance required for each policy finding |
| `exceptions_allowed` | Whether time-bound exceptions may be granted for this policy |
| `effective_from` | Date the policy becomes active |
| `version` | Semantic or monotonic policy version |

## Accepted Policy Formats

- OPA/Rego policies (infrastructure, deployment, admission control)
- JSON Schema or OpenAPI validation rules (configuration and APIs)
- Semgrep or code scanning rules (secure coding, banned patterns)
- YAML/JSON policy bundles with explicit conditions, severities, and metadata
- Exception manifests with approver, business justification, scope, and expiration

## Framework Mappings

| Framework | Example Controls |
|---|---|
| SOC2 | CC6.1 (logical access), CC7.2 (system monitoring), CC8.1 (change management) |
| HIPAA | 164.312(a)(1) access control, 164.312(e)(2)(ii) encryption |
| GDPR | Art. 25 (data protection by design), Art. 32 (security of processing) |
| FedRAMP | AC-2 account management, AU-9 protection of audit info, SC-28 at-rest protection |

## Exception Registry Schema

```yaml
exception:
  policy_id: "SEC-001"
  asset: "service/legacy-api"
  approver: "security-lead@example.com"
  business_justification: "Migration in progress, compliant by Q3"
  scope: "legacy-api service only"
  expires: "2026-09-30"
  risk_accepted: true
```

Expired or missing approvals are treated as active violations.

## Audit Report Format

```yaml
compliance_report:
  scan_date: "<ISO timestamp>"
  context: "ci | pre-commit | scheduled | release-gate"
  summary:
    total_checks: N
    passed: N
    failed: N
    exceptions_active: N
    exceptions_expired: N
  findings:
    - policy_id: "SEC-001"
      title: "<control name>"
      severity: "high"
      asset: "<file or resource path>"
      framework_controls: ["SOC2 CC6.1"]
      status: "violation | exception | pass"
      exception_expiry: "<date or null>"
      remediation: "<concise fix>"
  version_delta:
    new_controls: [...]
    changed_thresholds: [...]
    retroactive_impact: [...]
```
