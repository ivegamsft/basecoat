---
name: security-operations
title: Security Operations & Threat Detection
description: "Use when implementing threat detection, audit logging, secret rotation, or incident response automation. USE FOR: write SIEM or KQL detection rules, automate secret rotation workflow, centralize security audit logs, build security alert triage playbook, monitor cloud or Kubernetes threats. DO NOT USE FOR: one-time app pentest reports, feature UX design."
compatibility: GHCP
---

# Security Operations Skill

Patterns for threat detection, secrets management, audit logging, and incident response automation across cloud-native (Azure, AWS) and Kubernetes environments.

## Reference Files

| File | Contents |
|------|----------|
| [`references/threat-detection-patterns.md`](references/threat-detection-patterns.md) | Auth attack detection, data access anomalies, privilege escalation, KQL/Bash queries |
| [`references/secrets-management.md`](references/secrets-management.md) | Automated credential rotation, Vault audit logging, rotation policies |
| [`references/audit-logging.md`](references/audit-logging.md) | ELK Stack config, log parsing, immutable audit trails, retention policies |
| [`references/incident-response-automation.md`](references/incident-response-automation.md) | Alert triage, false positive detection, threat correlation, escalation workflows |
| [`references/monitoring-metrics.md`](references/monitoring-metrics.md) | Key security metrics, alert configuration, dashboarding strategies |
| [`references/security-operations-playbooks.md`](references/security-operations-playbooks.md) | Incident runbooks, escalation procedures, post-incident analysis templates |
