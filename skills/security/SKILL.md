---
name: security
compatibility: [github-copilot-cli]
description: "Use when auditing code, modeling threats, or reviewing dependencies for exploitable weaknesses. USE FOR: run OWASP security review, create STRIDE threat model, scan for hardcoded secrets, audit dependencies for CVEs, write structured vulnerability report. DO NOT USE FOR: live incident response handling, general performance tuning."
---
# Security Skill

Audit code for security vulnerabilities, model threats, review dependencies for known CVEs, and enforce secure coding standards.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `owasp-checklist.md` | OWASP Top 10 evaluation checklist with pass/fail tracking per category |
| `stride-threat-model-template.md` | STRIDE threat modeling template for enumerating and rating threats per component |
| `vulnerability-report-template.md` | Structured vulnerability report for compiling all findings with severity ratings |
| `dependency-audit-template.md` | Dependency audit template for documenting CVEs, affected packages, and remediation |

## Agent Pairing

Use with `security-analyst` agent. For backend security pair with `backend-dev`; for frontend security (CSP, XSS, CORS) pair with `frontend-dev`.

## Related Guardrails

- [Security Findings Triage](references/security-findings-triage.md) — SLA-based triage process for severity classification, ownership, and remediation tracking
- [Remediation Closure Evidence Template](references/remediation-closure-evidence-template.md) — Required evidence fields for implementation-linked closure and risk-acceptance records


