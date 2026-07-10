# Canonical Security and Quality Intake Workflow

## Context

Issue: #1733  
Parent feature: #1737 (Wave 2)

Security alerts, quality findings, and Dependabot events currently enter
different triage paths with inconsistent contracts.

## Workflow Scope

- Security findings (SAST, dependency, secret scanning)
- Quality findings (review findings, lint/test gates, workflow policy checks)
- Dependabot findings and PR-linked dependency risk items

## Input Contract

All intake events must produce:

| Field | Required | Notes |
|---|---|---|
| `finding_source` | Yes | Source system id |
| `source_id` | Yes | Unique id in source system |
| `source_link` | Yes | URL to source artifact |
| `severity` | Yes | Canonical severity enum |
| `risk_domain` | Yes | `security` or `quality` (or both when mapped) |
| `affected_surface` | Yes | repo, component, path |
| `owner` | Yes | team or individual |
| `detected_at` | Yes | timestamp |
| `evidence` | No | populated at verification stage |

## Normalization Rules

1. Map source-specific severity to canonical severity scale.
2. Map source-specific category to canonical `risk_domain`.
3. Build dedupe key per #1735.
4. Populate canonical project model fields per #1732.

If normalization fails for required fields, intake creates a blocked triage item
with reason code and escalation label.

## Routing Rules

1. If dedupe match exists, attach source to canonical issue.
2. If no dedupe match, create new canonical issue and assign project metadata.
3. Apply deterministic labels:
   - `risk:<security|quality>`
   - `severity:<critical|high|medium|low>`
   - `source:<origin>`
   - sprint label when in active sprint scope

## Traceability Contract

Every intake action must preserve:

- source artifact URL
- canonical issue URL
- duplicate/canonical linkage (if applicable)
- remediation PR URL (when available)
- verification evidence URL (once available)

## Failure Handling

Failure modes and behavior:

1. **Missing required fields:** block creation and raise triage-needed issue.
2. **Conflicting canonical candidates:** resolve with #1735 rules and log audit event.
3. **Assignment failure:** keep item open with explicit `owner-missing` label.

No silent drops are allowed.

## Acceptance Criteria Mapping

- [x] Canonical workflow document exists.
- [x] Input/output contract is defined.
- [x] Source-to-issue mapping rules are explicit.
