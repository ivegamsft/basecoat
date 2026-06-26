---
name: azure-waf-review
compatibility: [github-copilot-cli]
description: "Use when assessing an Azure workload against the Well-Architected Framework and prioritizing remediation. USE FOR: run an Azure Well-Architected review, score a workload across WAF pillars, review Terraform or Bicep for reliability and security gaps, prioritize remediation actions, assess an architecture before production. DO NOT USE FOR: penetration testing, incident response triage, writing new product features."
category: infrastructure

context: fork
---
# Azure Well-Architected Framework Review Skill

Assess Azure workloads against the five WAF pillars, generate scored findings reports, and
produce prioritized remediation guidance with Bicep/Terraform templates.

## Reference Files

| File | Contents |
|------|----------|
| [`references/pillar-guide.md`](references/pillar-guide.md) | Five WAF pillars with key concerns, full 7-step assessment workflow, template index, all references |
| [`references/workflow-guardrails.md`](references/workflow-guardrails.md) | Guardrails for scope, secrets, and advisory use; agent pairing guidance |

## Key Patterns

- Score each pillar 1–5; flag findings Critical / High / Medium / Low
- Rank by impact × effort matrix — surface quick wins first
- Never emit secrets or credentials in generated IaC
- Pair with `solution-architect` (full assessment) and `devops-engineer` (IaC remediation)
