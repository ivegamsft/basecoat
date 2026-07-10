# Testing and Quality Remediation Project Model

## Context

Issue: #1732  
Parent feature: #1737 (Wave 1)

Security and quality remediation work is currently tracked across multiple issue
types with inconsistent metadata. That creates blind spots for SLA tracking,
ownership, and verification throughput.

## Design Goals

1. Define a canonical project schema for grouped remediation work.
2. Preserve downstream repository delivery fields while enforcing required
   governance fields.
3. Enable deterministic automation for intake, triage, and reporting.
4. Support status transitions that are compatible with verification-first
   closure policy.

## Canonical Project Fields

| Field | Type | Required | Purpose |
|---|---|---|---|
| `canonical_id` | string | Yes | Stable key for dedupe and cross-linking |
| `finding_source` | enum | Yes | `codeql`, `dependabot`, `secret-scan`, `manual-review`, `quality-review` |
| `severity` | enum | Yes | `critical`, `high`, `medium`, `low` |
| `risk_domain` | enum | Yes | `security`, `quality`, `reliability`, `compliance` |
| `verification_status` | enum | Yes | `unverified`, `pending_verification`, `verified` |
| `lifecycle_status` | enum | Yes | `open`, `fixed_pending_verification`, `verified`, `resolved` |
| `owner` | string | Yes | Directly accountable engineer or team |
| `due_date` | date | Yes | SLA deadline |
| `evidence_link` | url[] | Conditional | Required for `verified` and `resolved` |
| `source_link` | url[] | Yes | Link to original alert/PR/finding |
| `remediation_pr` | string | Conditional | Required when status >= `fixed_pending_verification` |

## Grouping Model

Grouped remediation views must support three orthogonal pivots:

1. **Feature theme:** sprint feature tracker and epic scope.
2. **Risk domain:** security vs. quality vs. reliability.
3. **Execution lane:** intake, triage, remediation, verification, resolved.

Group keys are computed from:

- `risk_domain`
- `severity`
- owning team
- sprint label

## Automation Contract

### Intake

- New findings must populate all required canonical fields.
- If any required field is missing, automation creates a blocked triage record
  with `lifecycle_status=open` and `verification_status=unverified`.

### Triage

- Triage automation assigns severity and owner.
- SLA due date is computed from severity policy:
  - critical: 2 business days
  - high: 5 business days
  - medium: 10 business days
  - low: 20 business days

### Status updates

- Transition `open -> fixed_pending_verification` requires `remediation_pr`.
- Transition `fixed_pending_verification -> verified` requires evidence links.
- Transition `verified -> resolved` requires source-link backfill and no open
  duplicates (as defined in #1735).

## Reporting Metrics

Required dashboards:

1. Open risk by severity and domain.
2. Aged findings past SLA.
3. Verification throughput (`fixed_pending_verification` to `verified` cycle time).
4. Duplicate rate and canonical resolution rate.
5. Owner-level backlog and SLA breach count.

## Required vs. Preserved Fields

The enforcement layer must distinguish canonical minimums from downstream
repository customizations:

- **Required/enforced:** canonical fields listed above.
- **Preserved/pass-through:** downstream labels, team-specific workflow tags,
  and repository-local metadata that do not conflict with canonical values.

## Acceptance Criteria Mapping

- [x] Project schema documented.
- [x] Grouping and status flow defined.
- [x] Required dashboards and metrics specified.
