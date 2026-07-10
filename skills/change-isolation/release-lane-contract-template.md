# Release Lane Contract Template

Use this template to define an independently releasable lane.

## Lane Identity

- **Lane name:** `<lane-name>`
- **Owned paths:** `<glob patterns>`
- **Owning team:** `<team>`
- **Primary workflow(s):** `<workflow file names>`

## Versioning

- **Scheme:** `<semver | date-based | commit-sha>`
- **Tag format:** `<example: mobile-v1.4.0>`
- **Breaking-change policy:** `<rules>`

## Promotion Flow

1. **Build/Test:** `<workflow + required checks>`
2. **Staging Deploy:** `<workflow + environment>`
3. **Production Deploy:** `<workflow + approvals>`

## Coupling Rules

- **Allowed inbound dependencies:** `<list>`
- **Allowed outbound dependencies:** `<list>`
- **Shared contract paths:** `<list>`
- **Disallowed triggers:** `<list>`

## Rollback

- **Rollback command/workflow:** `<details>`
- **Data rollback requirement:** `<yes/no + method>`
- **SLA/MTTR target:** `<target>`

## Guardrails

- Required reviewers for boundary changes: `<owners>`
- Required policy checks: `<checks>`
- Alerting/telemetry for failed promotions: `<signals>`
