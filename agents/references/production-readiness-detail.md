# Production Readiness — Detail

Supporting detail for [`agents/basecoat-10-core-production-readiness.agent.md`](../basecoat-10-core-production-readiness.agent.md).

## 1. Production Readiness Review (PRR) Gate

Use PRR as a hard gate with explicit pass criteria.

```yaml
PRR Checklist (Required):
  Deployment:
    - [ ] Rollout + rollback tested
    - [ ] Migration safety verified
    - [ ] Canary/feature-flag plan approved
  Security/Compliance:
    - [ ] Security review complete
    - [ ] Secrets/access controls validated
    - [ ] Required compliance checks passed
  Reliability:
    - [ ] Load/perf tests meet SLO targets
    - [ ] Monitoring, alerts, tracing in place
    - [ ] On-call and runbooks ready
  Documentation:
    - [ ] Architecture + known risks current
    - [ ] DR procedures published
    - [ ] Owners and escalation path assigned

PRR Decision Gate:
  APPROVED → Proceed to production
  APPROVED WITH CONDITIONS → Canary-only until conditions close
  REJECTED → Address failing criteria; resubmit
```

## 2. Business Continuity Planning (BCP)

Define how critical services stay available through major disruptions.

```yaml
BCP Components:
  Disruption Scenarios:
    - Regional outage
    - Primary database failure
    - Security incident response mode
    - Critical dependency outage
  Objectives:
    - Tier 1 services: RTO/RPO documented and tested
    - Tier 2/3 services: relaxed targets with owner sign-off
  Continuity Strategies:
    - Auto failover where possible
    - Manual failover runbook when automation is absent
    - Read-only degraded mode for critical paths
  Communication Plan:
    - Initial incident notice within agreed SLA
    - Regular status cadence during outage
    - Internal escalation chain and external comms owner
```

## 3. Disaster Recovery Planning (DRP)

Keep recovery procedures executable, tested, and owner-assigned.

```yaml
DRP Components:
  Backup/Restore:
    - Tiered backup frequency by service criticality
    - Retention policy with compliance alignment
    - Scheduled restore tests with evidence
  Runbooks:
    - Database corruption
    - Cache-layer outage
    - DNS/provider failure
  Recovery Tiers:
    - Tier 1: business-critical paths (minutes-scale)
    - Tier 2: important but non-critical services
    - Tier 3: archival and historical systems
```

## 4. Failure Mode & Effects Analysis (FMEA)

Prioritize mitigations using risk priority number (RPN).

```yaml
FMEA Steps:
  1. List plausible failure modes and existing controls
  2. Score severity, occurrence, and detection (1-10)
  3. Compute RPN = S × O × D
  4. Prioritize remediation by highest RPN
  5. Track owners and due dates for high-risk items
```

## 5. Incident Response Coordination

Ensure incidents can be detected, triaged, mitigated, and reviewed quickly.

```yaml
Incident Response Workflow:
  1. Detection and alert validation
  2. Triage and severity declaration
  3. Mitigation (rollback/failover/degradation)
  4. Resolution and customer communication
  5. Post-incident review with preventive actions
```

## Success Criteria

### Production Readiness

- PRR decisions are evidence-backed and auditable.
- Critical blockers are resolved before broad rollout.

### Business Continuity

- RTO/RPO targets exist for critical systems.
- Continuity exercises run on a recurring cadence.

### Disaster Recovery

- Restore drills validate recovery procedures.
- Tiered runbooks are current and owner-assigned.

### Incident Response

- On-call escalation and comms paths are verified.
- Post-incident actions are tracked to closure.

## References

- [NIST SP 800-61 Rev.3](https://csrc.nist.gov/pubs/sp/800/61/r3/final)
- [CIS Critical Security Controls](https://www.cisecurity.org/controls/cis-controls-list/)
- [ISO 22301: Business Continuity Management](https://www.iso.org/standard/75106.html)
- [OWASP Disaster Recovery Checklist](https://owasp.org/www-community/controls/Disaster_Recovery)
