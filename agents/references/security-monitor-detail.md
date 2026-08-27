# Security Monitor — Detail Reference

## Overview

The Security Monitor agent operationalizes the **NIST Cybersecurity Framework (CSF) 2.0 Detect function** through:

- **Detection Rule Development** — MITRE ATT&CK → detection queries (SIEM, EDR, WAF)
- **Alerting Baseline** — Alert noise reduction, tuning thresholds, escalation workflows
- **SIEM Query Templates** — Splunk, Elasticsearch, Azure Monitor KQL patterns
- **Threat Intelligence Integration** — TTP enrichment, indicator matching
- **Detection Validation** — Purple team exercises, tuning effectiveness

## Use Cases

### Primary

- Designing detection rules for known attack tactics (MITRE ATT&CK)
- Building SIEM alert logic aligned to NIST CSF Detect outcomes
- Establishing alerting baselines (tune for signal/noise ratio)
- Validating detection effectiveness through purple team exercises
- Mapping compliance requirements (SOC2 CC7.2, HIPAA, PCI DSS) to detections

### Secondary

- False positive reduction and alert fatigue mitigation
- Real-time vs. batch detection mode decisions
- Detection coverage gap assessment

## Core Concepts

### NIST CSF 2.0 Detect Function (illustrative subset)

| Outcome | Purpose | Example Detection |
|---------|---------|------------------|
| **DE.CM-01** | Networks monitored to find potentially adverse events | Beaconing detection, C2 domains |
| **DE.CM-02** | Physical environment monitored to find potentially adverse events | Badge swipe logs, tailgating alerts |
| **DE.CM-03** | Personnel activity/technology use monitored to find potentially adverse events | Account anomalies, insider-risk signals |
| **DE.CM-06** | External service provider activities monitored to find potentially adverse events | Vendor/API access anomalies |
| **DE.CM-09** | Computing hardware/software monitored to find potentially adverse events | Config drift alerts, unauthorized software |
| **DE.AE-02** | Potentially adverse events analyzed to characterize and clarify events | Correlated login-anomaly investigation |
| **DE.AE-03** | Information correlated from multiple sources | SIEM normalization, cross-source correlation |
| **DE.AE-06** | Information on adverse events is provided to authorized staff/tools | Detection-to-incident routing |
| **DE.AE-07** | Cyber threat intelligence and other contextual information integrated into analysis | TTP enrichment, indicator matching |
| **DE.AE-08** | Incidents are declared when adverse events meet defined criteria | Alert thresholds, severity definitions |

This is a representative subset for detection-engineering scope, not the full CSF 2.0 Detect category — validate outcome IDs against the current [NIST CSF 2.0 Core](https://csrc.nist.gov/publications/detail/cswp/29) before using in a compliance-facing report.

### MITRE ATT&CK → Detection Mapping

Each tactic has testable indicators:

```yaml
Reconnaissance:
  - DNS queries to unusual domains → DNS query logging + threat intelligence match
  - Whois lookups → Proxy logs, network monitoring
  - Network port scanning → IDS/IPS alerts, firewall logs

Initial Access:
  - Phishing emails → Email gateway logs + sandbox detonation
  - Exploitation of public-facing applications → WAF rules, vulnerability signatures

Persistence:
  - New user accounts created → Directory change auditing
  - Scheduled task creation → Windows Security Event 4698 (scheduled task created), correlated with Sysmon Event 1 (process creation) for `schtasks.exe`/PowerShell
  - Web shell deployment → File integrity monitoring, anomalous PHP execution
```

## Workflow Detail

### 1. MITRE ATT&CK Tactic Selection

Define which tactics are relevant to the organizational threat model.

```yaml
Priority Tactics (most common in observed breaches):
  - Persistence (add long-term footholds)
  - Defense Evasion (blend with normal activity)
  - Credential Access (steal credentials)
  - Discovery (map the network)
  - Lateral Movement (pivot to other systems)
  - Exfiltration (steal data)
  - Impact (disrupt or destroy)
```

### 2. Detection Rule Development

For each tactic/technique, define the detection query:

```yaml
Detection Rule Template:
  Title: "Suspicious PowerShell Command Execution (Defense Evasion)"
  MITRE ATT&CK: T1027 (Obfuscated Files or Information)

  Detection Query (Splunk):
    sourcetype=WinEventLog:Security EventCode=4688
    | where process_name="powershell.exe"
    | where like(command, "%DownloadString%") OR like(command, "%IEX%")
    | stats count by user, hostname, command
    | where count > 3

  Severity: High
  Response Action: "Isolate host, kill process, retrieve command history"
```

### 3. Alert Tuning & Thresholds

Establish baselines and thresholds to reduce false positives:

```yaml
Tuning Strategy:
  - Establish baseline activity (normal process execution patterns)
  - Set alert threshold above baseline (e.g., 3σ deviation)
  - Whitelist known-good processes/users
  - Implement time-series anomaly detection (seasonal spikes)
  - Define severity levels (Critical → Immediate response, Info → Routine review)
```

### 4. Incident Routing

Map detection types to incident response playbooks:

```yaml
Incident Routing:
  "Credential Access" → SOC Analyst → Incident Handler (Authentication)
  "Lateral Movement" → SOC Analyst → Incident Handler (Network) + Forensics
  "Exfiltration" → SOC Analyst → Incident Handler (Data Protection) + Legal/PR
  "Ransomware Behavior" → CRITICAL → Incident Commander + Backup Team + Leadership
```

## Required Skills

- **skills/security/** — OWASP checklists, vulnerability report template, STRIDE threat model template (`skills/security/SKILL.md`)

## Integration Points

- **SIEM** (Splunk, Azure Sentinel, Elastic) — Alert rule delivery
- **EDR** (CrowdStrike, Microsoft Defender) — Behavioral detection
- **Incident Responder** agent — Incident classification and remediation
- **Security Analyst** agent — Vulnerability context enrichment
- **Config Auditor** agent — Configuration baselines for drift detection

## Standards & References

- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [NIST CSF 2.0](https://csrc.nist.gov/publications/detail/cswp/29)
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
- [CIS Controls v8 — Control 8 & 9 (Logging & Monitoring)](https://www.cisecurity.org/controls)
- [SOC2 CC7.2 — Monitor System Components & Information for Anomalies](https://us.aicpa.org/interestareas/informationmanagement/sodp/content-landing)
