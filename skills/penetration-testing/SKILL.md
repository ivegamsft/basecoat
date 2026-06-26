---
name: penetration-testing
compatibility: [github-copilot-cli]
title: Penetration Testing & Vulnerability Discovery Patterns
description: "Use when executing authorized penetration tests, validating OWASP risks, or producing exploit-backed findings. USE FOR: test for SQL injection or SSRF, run OWASP Top 10 web assessment, validate broken access control, reproduce API auth bypass, write penetration test findings report. DO NOT USE FOR: testing without authorization, destructive load testing in production."
category: security
---
# Penetration Testing Skill

Patterns for executing penetration tests aligned with OWASP standards, covering
reconnaissance, vulnerability discovery, exploitation, and reporting.

## Quick Navigation

| Reference | Contents |
|---|---|
| [references/test-cases.md](references/test-cases.md) | Test harness, OWASP coverage matrix, web application testing patterns |
| [references/exploitation.md](references/exploitation.md) | Common vulnerability exploitation (SSTI, XXE, deserialization, API flaws) |
| [references/reporting.md](references/reporting.md) | Finding template, CVSS scoring, remediation payloads |

## Test Execution Flow

```text
1. Scope definition → agree on targets and allowed techniques
2. Reconnaissance   → enumerate endpoints, gather tech stack info
3. Vulnerability discovery → OWASP Top 10 test cases
4. Exploitation     → validate severity by demonstrating impact
5. Reporting        → finding template per vulnerability, CVSS score
6. Remediation      → provide fix code, verify fix in retest
```

## Scope Rules

- Never test without written authorization
- Stop and escalate immediately if RCE or credential dump is found
- Do not exfiltrate real user data — stop at proof-of-concept level
