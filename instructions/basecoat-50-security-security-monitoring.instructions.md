---
description: >
  Security monitoring standards for SIEM integration, alert configuration,
  detection rule development, and incident escalation workflows.
applyTo: agents/security-monitor.agent.md, agents/config-auditor.agent.md, agents/incident-responder.agent.md
---

# Security Monitoring Standards

## SIEM Integration

When instrumenting applications for security monitoring:

- **Normalization:** Map all log formats to a common schema (CEF, Syslog, or JSON).
- **Enrichment:** Add context (user, asset, location, threat intelligence) to every event.
- **Parsing:** Define field extraction patterns per source type.
- **Retention:** Set retention per compliance requirement (SOC2: 90 days, HIPAA: 6 years, PCI-DSS: 1 year).

Alert rules follow this pattern: Name, Type (Correlation/Anomaly/Threshold), Severity, MITRE ATT&CK technique, detection query, baseline, threshold, response actions, and escalation path.

See [siem-and-alerts.md](references/security-monitoring/siem-and-alerts.md) for Splunk config examples, alert templates, and false-positive tuning guidance.

## Detection Rule Development

Every detection rule maps to a MITRE ATT&CK technique. Three standard query templates:

1. **Behavioral Anomaly (Statistical):** Baseline normal, detect spike (count > 3× 7-day average).
2. **IoC Match:** Filter events against threat intelligence feeds (CISA, VirusTotal).
3. **Impossible Travel:** Flag logins from geographically impossible locations (speed > 900 mph).

See [detection-rules.md](references/security-monitoring/detection-rules.md) for MITRE ATT&CK mapping rules, query templates, and log schema.

## Incident Escalation

| Severity | Example | Response Time | Action |
|---|---|---|---|
| **P0 / Critical** | Active data exfiltration, ransomware | 15 min | Incident Commander → Full mobilization |
| **P1 / High** | Lateral movement, privilege escalation | 1 hour | SOC Analyst → Incident Handler |
| **P2 / Medium** | Suspicious network traffic, policy violation | 4 hours | SOC Analyst → Investigation queue |
| **P3 / Low** | Single failed login, known-good process | 1 day | Logged for trends analysis |

On-call rotations: SOC Analyst (24/7 triage), Incident Handler (24/7 confirmed incidents), Incident Commander (on-demand P0/P1), Forensics (business hours + escalation).

See [incident-escalation.md](references/security-monitoring/incident-escalation.md) for the full escalation workflow, on-call structure, and compliance mappings (SOC2/HIPAA/PCI-DSS).

## Reference Files

| File | Contents |
|---|---|
| [siem-and-alerts.md](references/security-monitoring/siem-and-alerts.md) | SIEM config, alert templates, false-positive tuning |
| [detection-rules.md](references/security-monitoring/detection-rules.md) | MITRE ATT&CK mapping, query templates, log schema |
| [incident-escalation.md](references/security-monitoring/incident-escalation.md) | Escalation workflow, on-call rotations, compliance |

## See Also

- `secrets-management.instructions.md` — Secrets revocation and break-glass procedures.
- `observability.instructions.md` — Structured logging schema and log aggregation.
