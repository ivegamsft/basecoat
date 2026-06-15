---
name: azure-identity-audit
description: "Use when reviewing Azure identity and access designs across RBAC, managed identities, Entra ID, and federation. USE FOR: audit RBAC assignments, managed identity scope, app registration permissions, OIDC federation, least privilege. DO NOT USE FOR: network topology design, app feature code, non-Azure IAM platforms."
compatibility:
  - GHCP
---
# Azure Identity Audit Skill

Review Azure identity and access designs for least privilege, federation hygiene, and scope correctness.

## USE FOR

- Auditing RBAC assignments and scope boundaries
- Checking managed identities, app registrations, and federated credentials
- Reviewing least-privilege decisions for Azure workloads
- Verifying conditional access or auth assumptions are explicit

## DO NOT USE FOR

- General network topology design
- Application feature implementation
- Non-Azure identity platforms
- Pure infrastructure provisioning without identity review

## Workflow

1. Identify every principal, scope, and trust boundary.
2. Verify the identity type matches the workload and hosting model.
3. Check permissions for least privilege and privilege escalation risk.
4. Confirm secret-free federation or credential storage where possible.
5. Summarize any gaps in scope, permissions, or ownership.

## Output

Return:

- Verdict: pass, pass with notes, or request changes
- Findings with evidence and affected scope
- Least-privilege gaps or over-broad grants
- Suggested remediation steps

## Related Agent

Use with `identity-architect` agent.
