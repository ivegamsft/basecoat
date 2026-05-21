---
name: config-secrets-audit
description: "Use when performing a deep, cross-environment configuration and secrets audit of a codebase. USE FOR: inventory all configuration sources across environments, classify sensitive keys and credentials without copying actual values, audit CI/CD and IaC for secret hygiene, produce a metadata-only findings report covering config files, env vars, secrets managers, CI/CD variables, and infrastructure parameters. DO NOT USE FOR: live secret rotation or revocation, general OWASP vulnerability scanning, runtime penetration testing."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Security & Compliance"
  tags: ["config-audit", "secrets", "multi-environment", "inventory", "classification", "compliance"]
  maturity: "production"
  audience: ["security-engineers", "platform-teams", "devops-engineers", "architects"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Config & Secrets Audit Skill

Reference knowledge, classification taxonomy, and report templates for performing a
comprehensive, metadata-only configuration and secrets audit across all environments
and configuration sources.

## Configuration Source Taxonomy

| Source category | What to look for | Common file patterns |
|---|---|---|
| **Application config** | Settings files, appsettings, web.config | `appsettings*.json`, `web.config`, `app.config`, `config/*.json`, `*.yaml` |
| **Environment variables** | Local and containerized env definitions | `.env`, `.env.*`, `docker-compose.yml`, `Dockerfile` `ENV` directives |
| **CI/CD variables** | Pipeline-injected secrets and variables | `.github/workflows/*.yml`, `azure-pipelines.yml`, `.circleci/config.yml`, `Jenkinsfile` |
| **Infrastructure-as-code** | Terraform/Bicep/ARM variable files | `*.tfvars`, `*.tfvars.json`, `*.bicepparam`, `parameters/*.json`, `terraform.tf` |
| **Kubernetes / Helm** | ConfigMaps, Secret manifests, Helm values | `*configmap*.yaml`, `*secret*.yaml`, `values.yaml`, `values-*.yaml` |
| **Container config** | Image build args, runtime env | `Dockerfile`, `docker-compose*.yml`, `.dockerenv` |
| **Secrets manager refs** | References to vault resources | Key Vault URI patterns, `@Microsoft.KeyVault(...)`, SSM Parameter Store paths, Secrets Manager ARNs |
| **Framework config** | Language/framework-specific config | `settings.py`, `database.yml`, `application.properties`, `config/database.js` |

## Sensitive Value Classification

Classify each key name (not value) found into one of these categories:

| Class | Examples | Risk if exposed |
|---|---|---|
| `API_KEY` | Stripe, SendGrid, Twilio, third-party SaaS keys | Medium–High: service abuse, billing fraud |
| `CREDENTIAL` | Username/password pairs, service account passwords | High: account takeover |
| `CONNECTION_STRING` | Database, Redis, Service Bus connection strings | Critical: full data access |
| `CLOUD_IDENTITY` | TenantId, ClientId, ClientSecret, SubscriptionId, AppId | Critical: cloud resource access |
| `TOKEN` | PAT, OAuth token, bearer token, JWT signing secret | High: impersonation, data access |
| `CERTIFICATE` | TLS cert, private key, PFX/PEM paths | Critical: MITM, impersonation |
| `ENCRYPTION_KEY` | AES keys, HMAC secrets, signing secrets | Critical: data exposure or forgery |
| `INFRASTRUCTURE` | SSH keys, VPN credentials, registry tokens | High: infrastructure compromise |
| `PII_ADJACENT` | Email addresses, user IDs, tenant slugs in config | Low–Medium: GDPR/privacy risk |
| `PLACEHOLDER` | `<value>`, `REPLACE_ME`, `__SECRET__` | Informational: verify substitution at deploy |

## Storage Pattern Assessment

For each sensitive key found, record the **storage pattern**:

| Pattern | Risk level | Description |
|---|---|---|
| `HARDCODED` | 🔴 Critical | Literal value in source-controlled file |
| `ENV_UNPROTECTED` | 🟠 High | Value in a `.env` file that may be committed |
| `ENV_REFERENCED` | 🟢 Good | `${ENV_VAR}` or `$(VAR)` reference — no value in code |
| `VAULT_REFERENCED` | 🟢 Best | `@Microsoft.KeyVault(...)`, `secretKeyRef`, SSM ARN |
| `CI_SECRET_REFERENCED` | 🟢 Good | `${{ secrets.MY_SECRET }}` — CI/CD platform managed |
| `PLACEHOLDER` | 🟡 Medium | Template placeholder — verify runtime substitution |
| `ENCRYPTED_AT_REST` | 🟢 Good | Value is encrypted, key managed separately |
| `UNKNOWN` | 🟡 Medium | Pattern unclear — manual review needed |

## Report Template

See [`report-template.md`](report-template.md) for the full structured report format.

## Agent Pairing

Primary agent: `config-secrets-audit` agent.

Complementary agents:
- `config-auditor` — git-tracked file scanning and `.gitignore` coverage
- `secrets-manager` — rotation, lifecycle, and vault migration after audit
- `github-security-posture` — org-level secret scanning policy status
- `security-analyst` — OWASP and threat modeling if vulnerabilities surface
