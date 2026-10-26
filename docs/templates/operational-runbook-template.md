# Operational Runbook Template

> **Scope:** Provider-neutral starting point for a service-specific runbook.
> This template does not describe a particular BaseCoat deployment.

## Document Control

| Field | Value |
|---|---|
| Service or system | `[name]` |
| Owner | `[team or role]` |
| Environments | `[environments]` |
| Last reviewed | `[date]` |

## Purpose and Scope

Describe the service, supported operational tasks, and explicit exclusions. Link
to any provider- or implementation-specific runbooks rather than treating those
procedures as universal.

## Preconditions and Access

- Required role, permissions, and approval:
- Required tools and versions:
- Change window or safety constraints:
- Relevant dashboards and status pages:

## Health Checks and Diagnostics

| Signal | Healthy condition | Where to inspect | Escalation |
|---|---|---|---|
| `[signal]` | `[condition]` | `[dashboard or command]` | `[owner or action]` |

## Standard Procedures

### Procedure: `[task]`

1. **Preconditions:** `[checks and approvals]`
2. **Action:** `[provider-neutral action or link to a scoped procedure]`
3. **Expected result:** `[observable outcome]`
4. **Rollback or recovery:** `[safe reversal or escalation]`
5. **Verification:** `[checks that confirm service health]`

## Incident Response

1. Identify scope and user impact.
2. Preserve relevant logs and evidence.
3. Mitigate using an approved procedure.
4. Escalate to `[team or role]` if the service does not recover.
5. Record the outcome and follow-up actions.

## Provider- or Implementation-Specific Procedures

Keep concrete commands and provider-specific steps in a clearly labeled
subsection. State the provider, IaC tool, and implementation in the subsection
title or a leading scope note.

### Example: `[provider]` with `[IaC tool]`

`[link to a separately scoped procedure; do not put unlabeled provider commands here]`

## References

- Service documentation: `[link]`
- Monitoring and alerting: `[link]`
- Scoped implementation runbook: `[link, if applicable]`
