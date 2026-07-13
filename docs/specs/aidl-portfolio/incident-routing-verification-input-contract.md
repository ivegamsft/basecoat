# Incident Routing Verification Input Contract

Input contract for `scripts/aidl-incident-routing-verification.ps1`. The script consumes a
JSON export (`incident-routing-export.json`) and scores it against the reliability audit
contract in [`audit-reliability.md`](audit-reliability.md). Scoring is offline and
deterministic; the script performs no network calls.

## Top-level shape

A JSON array of incident record objects. The array must contain at least one record.

```json
[
  { "incident_id": "INC-1001", "severity": "SEV1", "status": "closed" }
]
```

## Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `incident_id` | string | Yes | Unique and immutable. A missing value produces a deterministic `MISSING-ID-<n>` placeholder and fails the record; duplicates fail. |
| `severity` | string | Yes | One of `SEV1`, `SEV2`, `SEV3`, `SEV4`, `SEV5` (case-insensitive). Any other value fails the record. |
| `status` | string | Yes | Lifecycle enum: `open`, `investigating`, `identified`, `monitoring`, `mitigated`, `resolved`, `closed`. `resolved` and `closed` are closure states. Unknown values fail. |
| `owner` | string | Yes | Non-blank DRI. |
| `affected_service` | string | Yes | Non-blank. When `-AreaTaxonomyPath` is supplied it must match a known portfolio area. |
| `customer_impact` | string | Yes | Non-blank impact statement. |
| `detected_at` | ISO-8601 timestamp | Yes | Present and parseable; treated as UTC. |
| `remediation_created_at` | ISO-8601 timestamp | For routed incidents | Required when a remediation link is present; must be chronologically at or after `detected_at`. |
| `remediation_issue_url` | string (URL) | Yes for routed incidents | Immutable GitHub issue or PR URL: `https://github.com/<owner>/<repo>/(issues\|pull)/<n>`. Placeholders (for example `n/a`) do not count as linked. |
| `remediation_priority` | string | Yes for routed incidents | Must match the canonical severity map exactly: SEV1 `critical`, SEV2 `high`, SEV3 `medium`, SEV4/SEV5 `low`. A `priority:` prefix is accepted. |
| `verification_artifact_url` | string (URL) | Yes for closures | Immutable GitHub artifact: issue/PR, `actions/runs/<n>`, `commit/<sha>`, or `releases/(tag\|download)/<ref>`. Required for every closure. |
| `root_cause_summary` | string | For SEV1/SEV2 | Required for high/critical incidents. |
| `repeat_without_prior_verification` | boolean | No | Accepts JSON booleans and the strings `true`/`false`/`1`/`0`/`yes`/`no`. Any other non-empty value fails the record. |

## Accepted URL forms

- Remediation link: `https://github.com/<owner>/<repo>/issues/<n>` or `.../pull/<n>`.
- Verification artifact: the remediation forms plus `.../actions/runs/<n>`,
  `.../commit/<sha>`, `.../releases/tag/<ref>`, `.../releases/download/<ref>`.

## Example record

```json
{
  "incident_id": "INC-1001",
  "severity": "SEV1",
  "status": "closed",
  "detected_at": "2026-01-05T09:00:00Z",
  "remediation_created_at": "2026-01-05T13:00:00Z",
  "owner": "oncall-a",
  "affected_service": "payments-api",
  "customer_impact": "checkout unavailable",
  "root_cause_summary": "connection pool exhaustion",
  "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/1",
  "remediation_priority": "critical",
  "verification_artifact_url": "https://github.com/IBuySpy-Shared/basecoat/actions/runs/10",
  "repeat_without_prior_verification": false
}
```

## Optional area taxonomy

Pass `-AreaTaxonomyPath <file>` where the file is a JSON array of allowed portfolio areas.
When supplied, `affected_service` must match a listed area (case-insensitive) or the record
fails on `area_valid`.
