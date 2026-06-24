# Incident-to-Backlog Routing Policy

This document defines the canonical routing policy for the `incident-to-backlog-router` agent.
All routing decisions made by the agent are governed by this policy. Changes require a PR review
and update to the agent's implementation.

## Purpose

Prevent orphaned incidents by ensuring every resolved or in-progress incident produces a
corresponding GitHub remediation issue with required portfolio fields, routed to the correct
delivery queue based on severity.

## Severity Classification

| Severity | Definition | Examples |
|---|---|---|
| SEV1 | Critical outage — all users affected, revenue loss, or data integrity risk | Full service down, payment processing failure, data corruption |
| SEV2 | Major degradation — significant subset of users affected or SLO critically burned | Checkout latency >5x baseline, partial auth failure, >20% error rate |
| SEV3 | Moderate degradation — limited user impact, workarounds exist | Single region slowness, non-critical feature unavailable, alert noise spike |
| SEV4 | Minor issue — low user impact, no active SLO burn | Cosmetic bug surfaced in incident review, minor telemetry gap |
| SEV5 | Informational — detected in post-incident review or monitoring | Toil item, runbook improvement, alert tuning recommendation |

## Routing Policy

### Queue Definitions

| Queue | Description | Label |
|---|---|---|
| Current sprint | Assigned to the active sprint for immediate resolution | `sprint:{N}`, `wave:1` |
| Maintenance queue | Assigned to next sprint maintenance window | `sprint:{N+1}`, `wave:2`, `maintenance` |
| Backlog | Prioritized but unscheduled — enters sprint planning | `backlog` |

### Severity-to-Queue Mapping

| Severity | Target Queue | Issue Creation SLA | Fix SLA | Sprint Wave |
|---|---|---|---|---|
| SEV1 | Current sprint | < 2 hours | 24 hours | wave:1 |
| SEV2 | Current sprint | < 8 hours | 72 hours | wave:1 |
| SEV3 | Maintenance queue | < 24 hours | 1 week | wave:2 |
| SEV4 | Maintenance queue | < 72 hours | 2 weeks | none |
| SEV5 | Backlog | < 1 week | 1 sprint | none |

SLA clock starts at incident detection time (not resolution time).

## Field Population Mapping

Every remediation issue created by the router must have these portfolio fields populated:

| Portfolio Field | Source | Mapping Rule |
|---|---|---|
| `Type` label | Incident classification | Bug: known defect caused incident; Enhancement: missing runbook/alert/capability; Security: security finding involved; Chore: toil or missing automation |
| `Priority` label | Severity | SEV1 → `priority:critical`; SEV2 → `priority:high`; SEV3 → `priority:medium`; SEV4/5 → `priority:low` |
| `Risk` label | Severity + security flag | SEV1/2 or security_involved → `risk:high`; SEV3 → `risk:medium`; SEV4/5 → `risk:low` |
| `Guardrail State` | Environment context | Set `guardrail-active` if a deploy freeze or gate is in effect at routing time |
| `SRE Impact` | Incident `sre_impact` field | revenue_loss, user_facing_degradation, data_integrity, latency, availability, or none; default: availability for SEV1/2 |
| `Wave` | Severity | SEV1/2 → `wave:1`; SEV3 → `wave:2`; SEV4/5 → no wave label |
| `Sprint` label | Routing target | SEV1/2 → `sprint:{current}`; SEV3 → `sprint:{next}`; SEV4/5 → `backlog` |
| `incident-followup` label | All incidents | Applied to every remediation issue for cross-cut reporting |

### Required Label Set

Every remediation issue must carry:

```
{type}  {priority}  {risk}  incident-followup  sprint:{N} OR backlog
```

Optional labels applied when conditions are met:

```
wave:1 OR wave:2       (SEV1-3 only)
maintenance            (SEV3/4 maintenance queue)
guardrail-active       (when deploy freeze is in effect)
security               (when security_involved = true)
```

## Escalation and Ownership Rules

### Escalation Triggers

The router escalates to a human when:

| Condition | Action | Escalation Target |
|---|---|---|
| Severity cannot be determined from incident data | Flag issue as `needs-triage`; do not route | On-call lead |
| Incident involves active data loss or breach | Mark `priority:critical`, `risk:high`, `security`; page on-call | Security on-call + engineering lead |
| Sprint is at capacity and SEV1/2 must enter current sprint | Alert sprint lead before assignment; document in routing log | Sprint lead / product owner |
| Orphaned incident exceeds 24-hour grace period | Auto-create remediation issue and notify incident owner | Incident commander (from incident issue body) |
| Duplicate remediation issue detected and both are open | Flag both for human resolution; do not merge automatically | Issue owner |

### Ownership Assignment Rules

| Severity | Default Assignee | Fallback |
|---|---|---|
| SEV1 | Incident commander from incident issue | On-call engineer |
| SEV2 | Incident commander or service owner | Engineering lead |
| SEV3 | Service owner or on-call | Team backlog owner |
| SEV4/5 | Team backlog owner | Unassigned (sprint planning) |

Ownership is populated in the remediation issue `assignee` field when the incident issue identifies a commander or owner. If no owner is identifiable, leave unassigned and add `needs-owner` label.

### Sprint Capacity Guard

Before routing SEV1/2 to the current sprint:

1. Use the `flow-admission-control` skill to check current sprint WIP against capacity limits.
2. If sprint WIP is at or above the defined limit:
   - Create the issue in the current sprint regardless (severity overrides capacity).
   - Post a sprint capacity warning comment on the issue.
   - Notify the sprint lead via a GitHub issue comment on the sprint tracking issue (if one exists).
3. Document the capacity override in the routing decision log.

## Orphan Prevention Protocol

An orphaned incident is an incident issue that is open or recently closed (within 14 days) with no
linked remediation issue in its body or comments.

### Detection

Run orphan detection on demand or on a scheduled cadence:

```bash
gh issue list --repo {repo} --state open \
  --label "incident" --json number,title,body,labels,comments \
  | jq '[.[] | select(
      (.body | contains("Remediation issue created") | not) and
      (.comments[] | .body | contains("Remediation issue created") | not // true)
    )]'
```

### Response Protocol

| Age of orphan | Action |
|---|---|
| < 2 hours | No action — within normal resolution delay |
| 2–24 hours | Post warning comment on incident issue |
| > 24 hours | Auto-create remediation issue; add `orphan-risk` label to incident |
| > 72 hours (SEV1/2) | Escalate to engineering lead; add `escalated` label |

### Closure Linkage Contract

A remediation issue is considered linked to an incident when:

1. The remediation issue body contains `Closes incident: {incident_id}` or `Incident source: {url}`.
2. OR the incident issue body or a comment contains `Remediation issue created: #{number}`.

Both directions of linkage must be present before an incident is considered fully tracked.

## Post-Incident Review Gate

For SEV1 and SEV2 incidents, a post-incident review (PIR) is required before the remediation issue
can be closed. The agent adds a PIR gate checklist item to every SEV1/2 remediation issue:

```markdown
- [ ] Post-incident review conducted and documented
- [ ] PIR action items captured as sub-issues or follow-up issues
- [ ] Runbook updated with prevention steps
```

Closing a SEV1/2 remediation issue without completing the PIR checklist triggers a `definition-of-done` agent check that blocks the close.

## Routing Decision Audit

All routing decisions are logged using the `decision-log-capture` skill. The log entry includes:

- Incident ID and severity
- Target queue and sprint assignment
- Portfolio fields applied
- Capacity override (if any)
- Orphan detection result
- Timestamp and routing agent version

Decision logs are referenced in sprint retrospectives and post-incident reviews.

## Policy Version

| Version | Date | Summary |
|---|---|---|
| 1.0 | 2026-06-24 | Initial policy — implements issue #1743 |
