---
description: >
  Secrets management standards — never commit secrets to version control,
  use centralized Vault solutions, implement rotation, and audit all access.
applyTo: agents/secrets-manager.agent.md, agents/devops-engineer.agent.md, agents/infrastructure-deploy.agent.md
---

# Secrets Management Standards

## Core Principle

**NEVER commit secrets to version control.** This is the foundation of secrets management.

## Secrets Classification

| Type | Examples | Management |
|---|---|---|
| **Application** (Runtime) | API keys, DB credentials, JWT secrets, encryption keys | Vault-injected at deploy time, rotated per policy |
| **Infrastructure** | SSH keys, TLS certs, VPN creds, container registry tokens | Vault or cert manager, short-lived leases |
| **Supply Chain** | npm/PyPI tokens, CI runner credentials, git PATs | Vault or CI platform secrets store, minimize lifetime |

## Storage Patterns

- **Preferred:** Centralized Vault with workload identity (OIDC/mTLS → Kubernetes SA → Vault → temporary token). No long-lived keys in code.
- **Acceptable:** CI/CD deployment-time injection — retrieve from Vault at deploy, inject as env var or mounted file.
- **Last resort:** `.env` file for local dev only — never commit, always in `.gitignore`, document in `.env.example` with masked values.

See [classification-and-storage.md](references/secrets-management/classification-and-storage.md) for implementation details and Kubernetes + Vault setup.

## Rotation Policy

| Secret Type | Frequency | Automation |
|---|---|---|
| API Keys | 90 days | High (Vault native) |
| Database Passwords | 60 days | High (Vault rotation templates) |
| OAuth/JWT Tokens | 30 days | Automatic (built-in TTL) |
| TLS Certificates | 365 days (renew at day 30) | Medium (cert automation) |
| SSH Keys | 180 days | Manual (requires rollover) |
| Container Registry Tokens | 30 days | High (registry-native) |

See [rotation-and-scanning.md](references/secrets-management/rotation-and-scanning.md) for rotation workflow, Vault automation examples, and daily scanning commands.

## Emergency Revocation

When a secret is compromised:

1. **Revoke immediately** (0–5 min): `vault revoke secret/my-api-key`
2. **Alert stakeholders** (0–5 min): security team, incident ticket, #security channel
3. **Investigate** (5–30 min): audit logs, determine scope and unauthorized activity
4. **Mitigate** (30 min–2 h): generate and deploy new secret, verify reconnection
5. **Document** (2–4 h): post-incident review, updated controls, stakeholder communication

See [emergency-and-compliance.md](references/secrets-management/emergency-and-compliance.md) for break-glass procedures and SOC2/HIPAA/PCI-DSS compliance mappings.

## Never Commit Secrets

- Use `detect-secrets` pre-commit hook + `.secrets.baseline`.
- Add `.env`, `*.pem`, `*.key`, `secrets/` to `.gitignore`.
- Configure repository branch protection to block secrets in push (gitleaks, `secret-scan.yml`).

## Reference Files

| File | Contents |
|---|---|
| [classification-and-storage.md](references/secrets-management/classification-and-storage.md) | Secret types, Vault patterns, Kubernetes setup, CI/CD injection |
| [rotation-and-scanning.md](references/secrets-management/rotation-and-scanning.md) | Rotation workflow, Vault automation, expiry scanning, alerting |
| [emergency-and-compliance.md](references/secrets-management/emergency-and-compliance.md) | Break-glass procedure, emergency access, SOC2/HIPAA/PCI-DSS mappings |

## See Also

- `security-monitoring.instructions.md` — SIEM integration and alert rules.
- `governance.instructions.md` — Contribution policies and security review gates.
