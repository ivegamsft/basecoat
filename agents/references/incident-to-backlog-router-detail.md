# Incident-to-Backlog Router — Detail Reference

## Routing Policy and SLA Targets

| Severity | Target Queue | SLA (issue created) | Sprint Assignment |
|---|---|---|---|
| SEV1 | Current sprint | < 2 hours | Current sprint; wave:1 |
| SEV2 | Current sprint | < 8 hours | Current sprint; wave:1 |
| SEV3 | Maintenance queue | < 24 hours | Next sprint; wave:2 |
| SEV4 | Maintenance queue | < 72 hours | Maintenance queue — next sprint |
| SEV5 | Backlog | < 1 week | Backlog — unassigned sprint |

See also: [`docs/guides/incident-to-backlog-routing-policy.md`](../../docs/guides/incident-to-backlog-routing-policy.md)

## Severity-to-Priority Mapping

| Severity | GitHub Priority Label | Risk Label | Fix SLA |
|---|---|---|---|
| SEV1 | `priority:critical` | `risk:high` | 24 hours |
| SEV2 | `priority:high` | `risk:high` | 72 hours |
| SEV3 | `priority:medium` | `risk:medium` | 1 week |
| SEV4 | `priority:low` | `risk:low` | 2 weeks |
| SEV5 | `priority:low` | `risk:low` | 1 sprint |

## Portfolio Fields

| Portfolio Field | Derivation Rule |
|---|---|
| `Type` | From classification (bug/enhancement/security/chore) |
| `Priority` | From severity-to-priority map |
| `Risk` | From severity and `security_involved` flag |
| `Guardrail State` | `active` if a deploy gate or freeze is in effect |
| `SRE Impact` | From `sre_impact` input; default `availability` for SEV1/2 |
| `Wave` | SEV1/2 → `wave:1`; SEV3 → `wave:2`; SEV4/5 → none |

## Issue Body Template

```markdown
## Incident Remediation — {incident_id}

**Severity:** {severity}
**SRE Impact:** {sre_impact}
**Affected Service:** {affected_service}
**Guardrail State:** {guardrail_state}
**Risk:** {risk}

### Incident Summary

{description}

### Root Cause Hypothesis

_To be filled during or after incident review._

### Remediation Actions

- [ ] Immediate mitigation applied or confirmed
- [ ] Root cause identified
- [ ] Long-term fix implemented and verified
- [ ] Runbook updated or created
- [ ] Alert coverage verified for recurrence detection
- [ ] Post-incident review scheduled (SEV1/SEV2)

### SLA Target

Issue must be created within: {sla_target}
Fix must be merged within: {fix_sla}

### Incident Closure Linkage

Closes incident: {incident_id}
Incident source: {incident_source_url}
```

## Queue Assignment Commands

```bash
# SEV1/SEV2 — current sprint
gh issue edit {issue_number} --repo {repo} --add-label "sprint:{sprint},wave:1"
gh project item-add {project_number} --owner {owner} --url {issue_url}

# SEV3 — next sprint/maintenance
gh issue edit {issue_number} --repo {repo} --add-label "sprint:{next_sprint},wave:2,maintenance"

# SEV4 — maintenance queue
gh issue edit {issue_number} --repo {repo} --add-label "sprint:{next_sprint},maintenance"

# SEV5 — backlog
gh issue edit {issue_number} --repo {repo} --add-label "backlog"
```

## Orphan Detection Query

```bash
gh issue list --repo {repo} --state open \
  --label "incident" --json number,title,body,labels,comments \
  | jq '[.[] | select(
      ((.body // "") | contains("Remediation issue created") | not) and
      (any(.comments[]?; .body | contains("Remediation issue created")) | not)
    )]'
```

## Output YAML Schema

```yaml
incident_router_result:
  incident_id: "{incident_id}"
  severity: "{severity}"
  status: "ROUTED | DUPLICATE | ORPHAN_DETECTED | DRY_RUN"
  remediation_issue:
    number: {issue_number}
    url: "{issue_url}"
    queue: "sprint | maintenance | backlog"
    sprint: "{sprint | null}"
    wave: "{wave | null}"
  portfolio_fields:
    type: "{type}"
    priority: "{priority}"
    risk: "{risk}"
    guardrail_state: "{guardrail_state}"
    sre_impact: "{sre_impact}"
  sla:
    issue_creation_target: "{sla_target}"
    fix_target: "{fix_sla}"
    issue_created_at: "{iso_timestamp}"
  routing_decision_logged: true
```

## Integration with Related Agents

| Agent | Integration Point |
|---|---|
| `incident-responder` | Consumes incident signal output after mitigation phase |
| `sre-engineer` | Feeds reliability gap findings as SEV3/SEV4 incidents |
| `issue-triage` | Validates label and quality of created remediation issues |
| `backlog-rebalancer` | Receives routed issues for sprint capacity adjustment |
| `flow-admission-control` | Checks sprint capacity before SEV1/2 sprint assignment |
