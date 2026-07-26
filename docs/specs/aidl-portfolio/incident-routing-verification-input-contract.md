# Incident Routing Verification Input Contract

Input contract for `scripts/aidl-incident-routing-verification.ps1`. The script consumes a
JSON export (`incident-routing-export.json`) and scores it against the reliability audit
contract in [`audit-reliability.md`](audit-reliability.md). Scoring is deterministic. By
default it runs offline; with `-EnableOnlineVerification` it also performs `gh` API checks
to verify remediation/verification linkage for each incident.

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
| `remediation_created_at` | ISO-8601 timestamp | For routed incidents and `status = mitigated` | Required when a remediation link is present, and also required for `status = mitigated`; must be chronologically at or after `detected_at`. |
| `remediation_issue_url` | string (URL) | Yes for routed incidents | GitHub issue or PR URL: `https://github.com/<owner>/<repo>/(issues\|pull)/<n>`. Placeholders (for example `n/a`) do not count as linked. |
| `remediation_priority` | string | Yes for routed incidents | Must match the canonical severity map exactly: SEV1 `critical`, SEV2 `high`, SEV3 `medium`, SEV4/SEV5 `low`. A `priority:` prefix is accepted. |
| `verification_artifact_url` | string (URL) | Yes for closures | GitHub artifact URL accepted by offline shape checks: issue/PR, `actions/runs/<n>`, `commit/<sha>`, `blob/<sha>/<path>`, `checks/runs/<n>`, or `releases/(tag\|download)/<ref>`. In online mode, closure verification only passes with immutable evidence (`commit/<sha>`, `blob/<sha>/...`, `actions/runs/<n>/attempts/<k>`, `checks/runs/<n>`, or `releases/(tag\|download)/<ref>`) that is associated from remediation evidence text. |
| `root_cause_summary` | string | For SEV1/SEV2 | Required for high/critical incidents. |
| `repeat_without_prior_verification` | boolean | Yes | Accepts JSON booleans and the strings `true`/`false`/`1`/`0`/`yes`/`no`. Missing, blank, or any other value fails the record (fails closed). |

## Accepted URL forms

- Remediation link: `https://github.com/<owner>/<repo>/issues/<n>` or `.../pull/<n>`.
- Verification artifact: the remediation forms plus `.../actions/runs/<n>`,
  `.../commit/<sha>`, `.../blob/<sha>/<path>`, `.../checks/runs/<n>`,
  `.../releases/tag/<ref>`, `.../releases/download/<ref>`.
- Online immutable verification forms (for closed incidents with `-EnableOnlineVerification`):
  `.../commit/<sha>`, `.../blob/<sha>/<path>`, `.../actions/runs/<n>/attempts/<k>`,
  `.../checks/runs/<n>`, `.../releases/tag/<ref>`, `.../releases/download/<ref>`.

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
  "remediation_issue_url": "https://github.com/ivegamsft/basecoat/issues/1",
  "remediation_priority": "critical",
  "verification_artifact_url": "https://github.com/ivegamsft/basecoat/actions/runs/10",
  "repeat_without_prior_verification": false
}
```

## Optional area taxonomy

Pass `-AreaTaxonomyPath <file>` where the file is a JSON array of allowed portfolio areas.
When supplied, `affected_service` must match a listed area (case-insensitive) or the record
fails on `area_valid`.
