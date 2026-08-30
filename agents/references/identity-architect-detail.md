# Identity Architect Agent — Detail Reference

Full standards for `agents/basecoat-10-core-identity-architect.agent.md`.

## Required Identity Artifact Templates

- RBAC assignments: `skills/azure-identity/rbac-role-assignment-template.md`
- Managed identities: `skills/azure-identity/managed-identity-mapping-template.md`
- App registrations: `skills/azure-identity/app-registration-checklist.md`
- Workload federation: `skills/azure-identity/workload-identity-federation-template.md`
- Conditional access: `skills/azure-identity/conditional-access-policy-template.md`

## Zero Trust Design Principles

- **Verify explicitly** — every access request must be authenticated with MFA, device compliance, or equivalent signal. Never trust network location alone.
- **Use least-privileged access** — assign the narrowest possible role at the narrowest possible scope. Review and revoke stale assignments on a defined cadence.
- **Assume breach** — design identity architecture assuming an adversary has already breached the perimeter. Enforce short-lived tokens, PIM for privileged roles, and conditional access risk policies.
- **Prefer managed identities** over service principals with credentials wherever Azure supports them.
- **Prefer workload identity federation** over client secrets or certificates for CI/CD and workload-to-Azure authentication.
- **No wildcard permissions** — never grant `*.ReadWrite.All` or `Owner` at subscription scope without an approved exception.

## RBAC Design Standards

- Assign roles at the resource-group scope or narrower — never subscription-scope unless explicitly required.
- Gate `Owner` and `User Access Administrator` assignments behind PIM with approval workflows.
- Review all RBAC assignments quarterly. Revoke any assignment without an active justification.
- Custom role definitions must be stored in version control and validated in CI.

## Managed Identity Standards

- System-assigned identities: use for single-resource workloads where the identity lifecycle matches the resource.
- User-assigned identities: use when sharing identity across resources, or when the identity must survive resource deletion.
- Grant managed identities only the roles they need to fulfil their function — no standing `Contributor` at subscription scope.
- Access to Key Vault secrets must use the `Key Vault Secrets User` role (RBAC model), not legacy access policies.

## App Registration Standards

- One app registration per workload and environment — do not share registrations across environments in production.
- Client secrets must expire within 12 months. Certificates are preferred over secrets for production.
- Federated credentials replace secrets for CI/CD pipelines (GitHub Actions, Azure DevOps, GitLab).
- Permissions must be reviewed and re-approved on a defined cadence. Remove unused permissions immediately.
- Group membership claims must be limited to assigned groups — never emit all-groups tokens.

## Conditional Access Standards

- Every policy must exclude break-glass accounts.
- Policies must start in Report-only mode; enable only after reviewing sign-in logs for 7 days.
- Block legacy authentication in all environments — no exceptions without a time-limited approved waiver.
- Require MFA for all users signing into cloud resources, and require re-authentication on high-risk sign-ins.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Identity]`
- **Base labels:** `security,identity`
- **This domain's `Type`/`Resource / Principal`/`Environment` fields below
  replace the shared template's `Category`/`File`/`Line(s)` metadata
  block** — identity findings are scoped to a principal or resource, not a
  file or line.
- **Type:** `<RBAC over-permission | Missing managed identity | Stale credential | Missing CA policy | Missing federation>`
- **Resource / Principal:** `<resource or principal name>`
- **Environment:** `<dev | staging | production>`

| Finding | Severity | Labels |
|---|---|---|
| Service principal secret stored in source code | Critical | `security,identity,critical` |
| Long-lived credentials used where federation is available | High | `security,identity` |
| Wildcard permission (`*.ReadWrite.All`) granted without approval | High | `security,identity` |
| `Owner` or `User Access Administrator` without PIM | High | `security,identity` |
| App registration credential past expiry | High | `security,identity` |
| Stale RBAC assignment with no active justification | Medium | `security,identity,tech-debt` |
| Missing MFA conditional access policy | High | `security,identity` |
| Legacy authentication not blocked | High | `security,identity` |
| Break-glass account not excluded from CA policy | Medium | `security,identity` |
| Managed identity not used where available | Medium | `security,identity,tech-debt` |
