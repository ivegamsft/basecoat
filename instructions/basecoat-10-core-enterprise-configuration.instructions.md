---
description: "Enterprise-level GitHub Copilot policy configuration, including usage metrics enablement, seat management, and security policies."
applyTo: "references/enterprise-configuration/**/*.md,instructions/enterprise-configuration.instructions.md,.github/workflows/*.{yml,yaml}"
distribute: false
---

# Enterprise Configuration and Policy Setup

Best practices for configuring GitHub Copilot at the enterprise level: policies, seat management, usage metrics, and security controls.

## Guidelines

- Record the owning admin role, approval path, and rollback option for each policy change.
- Prefer documented API-backed workflows for metrics and seat management over manual screenshots or one-off notes.
- Review inactive seats, org access, and security policy drift on a recurring schedule.
- Keep rollout checklists explicit about prerequisites, validation, and communication steps.

## Prerequisites

- **Enterprise owner** or **Enterprise security admin** role
- `admin:enterprise` + `admin:org` OAuth scopes for API access
- Access to Enterprise → Settings → Policies

## Seat Management (Summary)

1. Enterprise → Settings → Policies → Copilot → Enable Copilot for organizations
2. Set seat limit based on headcount + growth projection
3. Grant org access and configure auto-assign or manual assignment
4. Monitor monthly — revoke seats inactive > 30 days

See [`references/enterprise-configuration/seat-management.md`](references/enterprise-configuration/seat-management.md) for API commands.

## Usage Metrics (Summary)

Enable via: Enterprise → Settings → Policies → Copilot → Usage metrics → Enable.

> **Note:** The old `GET /orgs/{org}/copilot/metrics` endpoint was **sunset 2026-04-02**.
> Use the reports API: `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest`

See [`references/enterprise-configuration/metrics-api.md`](references/enterprise-configuration/metrics-api.md) for full API reference and troubleshooting.

## Examples

### Example metrics API call

```bash
gh api \
  -H "Accept: application/vnd.github+json" \
  /orgs/contoso/copilot/metrics/reports/organization-28-day/latest
```

### Example rollout checklist entry

```text
Policy: Enable usage metrics
Owner: Enterprise admin
Validation: Reports API returns current 28-day snapshot
Rollback: Disable usage metrics policy and notify org admins
```

## Security Policies (Summary)

- **Code suggestions:** Enterprise → Policies → Copilot → Code suggestions (enable/disable/custom per org)
- **Public code matching:** Enterprise → Policies → Copilot → Public code matching (allow/disallow)
- **Secret scanning:** Enterprise → Security → Secret scanning → Enable for Copilot-generated code

## Setup Checklist

Five-phase rollout: Governance (Week 1) → Infrastructure (Week 2) → Observability (Week 3) → Security (Week 4) → Optimization (Month 2+).

See [`references/enterprise-configuration/security-and-checklist.md`](references/enterprise-configuration/security-and-checklist.md) for the full checklist and troubleshooting guide.

## References

| Topic | File |
|---|---|
| Seat assignment, grant access, monitor usage, revoke inactive | [`references/enterprise-configuration/seat-management.md`](references/enterprise-configuration/seat-management.md) |
| Enable metrics policy, API endpoints, NDJSON fields, common issues | [`references/enterprise-configuration/metrics-api.md`](references/enterprise-configuration/metrics-api.md) |
| Security policies, billing, 5-phase setup checklist, troubleshooting | [`references/enterprise-configuration/security-and-checklist.md`](references/enterprise-configuration/security-and-checklist.md) |

## See Also

- `instructions/security-monitoring.instructions.md` — Monitoring security posture
- `instructions/governance.instructions.md` — BaseCoat governance policies
- `instructions/observability.instructions.md` — Observability and metrics
