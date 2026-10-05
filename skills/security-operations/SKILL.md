---
name: security-operations
compatibility: [github-copilot-cli]
title: Security Operations & Threat Detection
description: "Use the security-operations skill for implementing security automation, distinct from the namesake SOC coordination agent. USE FOR: write SIEM or KQL detection rules, automate secret rotation workflow, centralize security audit logs, build security alert triage playbook. DO NOT USE FOR: live incident coordination (security-operations agent), one-time app pentest reports, feature UX design."
category: security
metadata:
  category: security
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Security Operations Skill

Patterns for threat detection, secrets management, audit logging, and incident response automation across cloud-native (Azure, AWS) and Kubernetes environments.

## Namespace Boundary

`security-operations` agent owns SOC triage, incident coordination, and playbook
guidance. This namesake skill owns detection-rule and automation implementation.
For an explicit request to coordinate an incident and implement rule changes,
keep the agent as coordinator and use this skill for the requested code work.
Neither namespace grants permission for live containment, credential rotation,
or deployment; retain the applicable approval and infrastructure gates.

## Reference Files

| File | Contents |
|------|----------|
| [`references/threat-detection-patterns.md`](references/threat-detection-patterns.md) | Auth attack detection, data access anomalies, privilege escalation, KQL/Bash queries |
| [`references/secrets-management.md`](references/secrets-management.md) | Automated credential rotation, Vault audit logging, rotation policies |
| [`references/audit-logging.md`](references/audit-logging.md) | ELK Stack config, log parsing, immutable audit trails, retention policies |
| [`references/incident-response-automation.md`](references/incident-response-automation.md) | Alert triage, false positive detection, threat correlation, escalation workflows |
| [`references/monitoring-metrics.md`](references/monitoring-metrics.md) | Key security metrics, alert configuration, dashboarding strategies |
| [`references/security-operations-playbooks.md`](references/security-operations-playbooks.md) | Incident runbooks, escalation procedures, post-incident analysis templates |
