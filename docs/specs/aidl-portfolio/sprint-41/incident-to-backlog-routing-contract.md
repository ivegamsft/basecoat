# Incident-to-Backlog Routing Contract (Sprint 41)

Execution contract for issue #2489. Turns the reliability audit criteria in
[`audit-reliability.md`](../audit-reliability.md) into a fixed, testable evidence model that
every production-impacting incident must satisfy before its backlog work is considered
routed. The offline verifier `scripts/aidl-incident-routing-verification.ps1` scores records
against this contract; its input format is defined in
[`incident-routing-verification-input-contract.md`](../incident-routing-verification-input-contract.md).

## 1. Incident classification fields

Every incident record must populate:

| Field | Requirement |
|---|---|
| `incident_id` | Unique and immutable; duplicates and missing IDs fail. |
| `severity` | One of `SEV1`, `SEV2`, `SEV3`, `SEV4`, `SEV5`; unknown values fail. |
| `affected_service` | Portfolio area/service; validated against a supplied area taxonomy when provided. |
| `customer_impact` | Explicit customer-impact statement. |
| `status` | Lifecycle enum `open`/`investigating`/`identified`/`monitoring`/`mitigated`/`resolved`/`closed`; `resolved` and `closed` are closures. |

## 2. Ownership and DRI expectations

- `owner` (DRI) is required: the evidence model verifies the `owner` field is present and
  non-blank. Assigning the DRI at incident-open time is the operational expectation; the
  offline model can only assert owner presence, not the assignment timestamp.
- A record missing an owner fails core-metadata completeness.

## 3. Backlog linkage and verification evidence

- `remediation_issue_url` must be a GitHub issue or PR URL
  (`https://github.com/<owner>/<repo>/(issues|pull)/<n>`). Placeholders (for example `n/a`)
  do not count as linked. (Issues/PRs are editable; see section 5 on closeout evidence for the
  immutable-versus-editable distinction.)
- `verification_artifact_url` must be a GitHub artifact URL. A `commit/<sha>` reference is
  unambiguously immutable and is the strongest evidence. A workflow run reference must be
  attempt-specific (`actions/runs/<n>/attempts/<k>`): a bare `actions/runs/<n>` is ambiguous
  because the run id is stable across reruns while `GITHUB_RUN_ATTEMPT` increments, so it does
  not identify a fixed attempt. Release/tag
  URLs (`releases/(tag|download)/<ref>`) are only conditionally immutable: a tag can be moved
  and a release asset replaced unless immutable-release protection is enabled, and the offline
  verifier accepts them by regex shape alone. They therefore count as immutable evidence only
  when release-protection or an artifact digest is verified; otherwise they are shape-only.
  Issue/PR URLs are accepted but are editable, so confirming they genuinely verify the fix
  requires the online linkage mode (#2507). The offline verifier regex-checks URL shape and
  type only.
- The chain is: incident record -> remediation issue/PR references the incident -> verification
  artifact confirms the fix -> closure references the verification artifact.
- The offline verifier validates URL **shape and type only** (that the links are GitHub
  issue/PR/run/commit/release URLs); it does not verify that a linked resource is immutable or
  unaltered. Confirming that the remediation actually references the incident ID and that
  closure references the verification artifact requires the online linkage mode tracked in
  #2507; until then, that cross-reference is asserted by the upstream collector, not
  re-verified offline.

## 4. Priority mapping (severity alignment)

Remediation priority must match the canonical map
([`incident-to-backlog-router-detail.md`](../../../../agents/references/incident-to-backlog-router-detail.md)):

| Severity | Required `remediation_priority` |
|---|---|
| SEV1 | `critical` |
| SEV2 | `high` |
| SEV3 | `medium` |
| SEV4 | `low` |
| SEV5 | `low` |

A routed incident with a missing or mismatched priority fails priority alignment (a
`priority:` prefix is accepted).

## 5. Closeout evidence requirements

- Every **closure** (`resolved`/`closed`) requires a valid `verification_artifact_url`;
  a closed record without one fails verification. To satisfy the immutable-evidence requirement
  in `audit-framework.md`, passing verification evidence must be an immutable reference. A
  commit SHA is unambiguously immutable; a workflow run reference must be attempt-specific
  (`actions/runs/<id>/attempts/<k>`) because a bare run id is shared across reruns; a release/tag
  reference qualifies only when immutable-release protection or an artifact digest is verified,
  since tags can move and release assets can be replaced. Current-versus-target: the
  verifier's `Test-GitHubArtifactUrl` today accepts issue and PR URLs by shape and marks such a
  closure `pass`, so editable references pass shape validation now but must not satisfy the
  immutable-evidence gate; tightening the verifier to warn or fail on editable references until
  an immutable one is supplied is the required Wave 2 change. URL shape alone never establishes
  that a fix was verified.
- `root_cause_summary` is required for all SEV1/SEV2 (high/critical) incidents, open or
  closed (per `audit-reliability.md` and the input contract), not only at closure.
- `detected_at` must be present and valid for every record; `remediation_created_at` is
  required only when a remediation link is present and must then be chronologically valid
  (`remediation_created_at >= detected_at`).
- Per `audit-reliability.md`, a record with `status = mitigated` requires a mitigation
  timestamp. The current verifier only validates `remediation_created_at` when a remediation
  link exists, so a mitigated record without a link has no mitigation-time check; adding an
  explicit mitigation-timestamp field and validating it for `status = mitigated` is the
  required Wave 2 hardening.
- Repeat incidents without prior verification are flagged. The offline verifier can only flag
  repeats when the producer supplies `repeat_without_prior_verification`; that field is
  currently optional and a missing value is treated as `false`, which passes. To honor the
  fails-closed guarantee, Wave 2 must require an explicit boolean with defined provenance for
  every record, or derive repeat history rather than trusting a defaulted value.

## 6. Scoring thresholds

| Metric | Target | Threshold |
|---|---|---|
| Routed incidents with remediation link | 100% | Warn < 100%, Fail < 95% |
| Verified closures (SEV1/SEV2) | 100% | Warn < 100%, Fail < 98% |
| Median incident-to-remediation latency | <= 1 business day | Warn > 1 day, Fail > 2 days |
| Repeat incidents without prior verification | 0 | Warn > 0, Fail >= 2 |

Deterministic, fails-closed scoring is the Wave 2 target: malformed, duplicate, or unverifiable
records should produce fail findings rather than passing. The current verifier does not yet
enforce this unconditionally; the documented current-versus-target exceptions above (editable
issue/PR evidence passing closure verification, a missing `repeat_without_prior_verification`
flag defaulting to `false`/pass, and mitigated records without remediation links skipping
mitigation-time validation) are the gaps Wave 2 must close to reach a fully fails-closed model.

**Overall status precedence**: per-record findings and per-metric statuses roll up into a
single overall status using worst-wins precedence over all statuses combined: the overall
status is `fail` if any status is `fail`, otherwise `warn` if any status is `warn`,
otherwise `pass`. This guarantees identical findings always yield the same overall outcome.

**Business day**: latency is measured in business days, computed as the number of weekday
hours between `detected_at` and `remediation_created_at` (Saturdays and Sundays excluded, no
holiday calendar), evaluated in UTC and divided by 24. For example, Friday to Monday is one
business day (24 weekday hours).

## Acceptance criteria mapping

- Incident classification fields defined -> section 1.
- Ownership and DRI expectations defined -> section 2.
- Backlog linkage and verification evidence requirements defined -> section 3, section 5.
- Priority mapping aligns to incident severity -> section 4.
- Closeout evidence requirements explicit -> section 5.
