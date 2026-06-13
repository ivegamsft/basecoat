---
name: azure-policy-audit
description: "Use when reviewing Azure Policy definitions, initiatives, exemptions, remediation tasks, or compliance reporting. USE FOR: audit policy coverage, remediation completeness, exemption hygiene, policy drift, compliance reporting. DO NOT USE FOR: app business logic, RBAC-only questions, generic troubleshooting."
compatibility: GHCP
---

# Azure Policy Audit Skill

Review Azure governance controls for coverage, remediation completeness, exemption hygiene, and compliance traceability.

## USE FOR

- Auditing Azure Policy definitions and initiatives
- Checking remediation tasks and DeployIfNotExists coverage
- Reviewing exemption usage, expiry, and justification quality
- Verifying compliance reports reflect the intended scope

## DO NOT USE FOR

- Application business logic
- RBAC-only access questions
- Generic troubleshooting without a policy concern
- Infrastructure changes that do not affect policy

## Workflow

1. Confirm the intended control and the scope it should cover.
2. Check the effect, parameters, and initiative composition for correctness.
3. Review exemptions for justification, expiry, and drift risk.
4. Validate remediation and reporting paths are complete.
5. Summarize gaps with severity, evidence, and next steps.

## Output

Return:

- Verdict: pass, pass with notes, or request changes
- Findings with severity and evidence
- Coverage gaps or false-positive risk
- Suggested remediation or policy update

## Related Agent

Use with `policy-as-code-compliance` agent.
