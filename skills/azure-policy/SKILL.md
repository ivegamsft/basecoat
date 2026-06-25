---
name: azure-policy
compatibility: [github-copilot-cli]
description: "Use when authoring Azure Policy definitions, initiatives, remediation tasks, and compliance reporting assets. USE FOR: write an Azure Policy to require tags, create a policy initiative for CIS controls, build a DeployIfNotExists remediation, generate a KQL compliance dashboard query, restrict allowed VM SKUs. DO NOT USE FOR: application business logic, Azure RBAC role selection, packet capture troubleshooting."
---
# Azure Policy & Governance Skill

Author Azure governance controls through custom policy definitions, policy initiatives,
remediation automation, and compliance reporting.

## Reference Files

| File | Contents |
|------|----------|
| [`references/workflow.md`](references/workflow.md) | 6-step authoring workflow: identify → define → bundle → remediation → KQL queries → framework mapping |
| [`references/guardrails.md`](references/guardrails.md) | Authoring guardrails and agent pairing guidance |
| [`policy-definition-template.md`](policy-definition-template.md) | Custom Azure Policy definition JSON |
| [`initiative-definition-template.md`](initiative-definition-template.md) | Policy initiative (set) definition |
| [`remediation-task-template.md`](remediation-task-template.md) | DeployIfNotExists remediation task |
| [`compliance-report-template.md`](compliance-report-template.md) | Azure Resource Graph and KQL compliance queries |


