---

name: azure-identity
description: "Use when designing Azure identity and access patterns across RBAC, managed identities, Entra ID, and workload federation. USE FOR: assign Azure RBAC roles, configure managed identity for an app, create an Entra ID app registration, set up GitHub OIDC federation, design a conditional access policy. DO NOT USE FOR: local password reset flows, network segmentation design, non-Azure IAM platforms."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Security & Compliance"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Azure Identity & Entra ID Skill

Design and implement Azure identity and access management — RBAC hierarchies, managed identities, Entra ID app registrations, conditional access policies, and workload identity federation.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `rbac-role-assignment-template.md` | RBAC role assignment matrix — principal-to-role-to-scope mappings |
| `managed-identity-mapping-template.md` | Managed identity catalogue — system-assigned and user-assigned per workload |
| `app-registration-checklist.md` | Entra ID app registration — API permissions, credentials, token configuration |
| `workload-identity-federation-template.md` | GitHub Actions OIDC and external identity provider federation |
| `conditional-access-policy-template.md` | Zero trust conditional access — users, devices, applications |

## Agent Pairing

Use with `identity-architect` agent. For IaC provisioning pair with `devops-engineer`; for app auth pair with `backend-dev` or `frontend-dev`; for threat modeling pair with `security-analyst`.
