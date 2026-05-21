# Configuration & Secrets Audit Report

> **Privacy rule:** This report contains NO actual secret values. All entries record
> key names, file paths, line numbers, storage patterns, and classifications only.
> If a value appears anywhere in this report, it must be redacted before sharing.

---

**Date:** <!-- ISO 8601 -->
**Repo:** <!-- remote URL or local path -->
**Auditor:** <!-- agent or analyst name -->
**Environments covered:** <!-- dev | staging | prod | all -->
**Scope:** <!-- full-repo | specific paths -->

---

## 1. Executive Summary

| Metric | Count |
|---|---|
| Configuration sources discovered | |
| Sensitive keys inventoried | |
| 🔴 Critical findings (hardcoded values) | |
| 🟠 High findings (unprotected env files) | |
| 🟡 Medium findings (placeholders unverified, unknown patterns) | |
| 🟢 Properly referenced (vault / CI secrets / env refs) | |
| Environments with gaps | |

**Overall posture:** <!-- Critical / High / Medium / Low / Clean -->

---

## 2. Configuration Source Inventory

| Source | Category | Path | Environments | Sensitive keys found | Notes |
|---|---|---|---|---|---|
| <!-- e.g. appsettings.json --> | Application config | <!-- path --> | dev, prod | <!-- count --> | |

---

## 3. Sensitive Key Inventory

> Keys listed by name only. Values are never recorded.

| Key name | File path | Line | Class | Storage pattern | Risk | Environment |
|---|---|---|---|---|---|---|
| <!-- DB_PASSWORD --> | <!-- config/settings.json --> | <!-- 42 --> | `CONNECTION_STRING` | `HARDCODED` | 🔴 Critical | prod |

---

## 4. Critical Findings — Hardcoded Values

For each `HARDCODED` or `ENV_UNPROTECTED` finding:

### Finding C-001

- **Key name:** `<!-- key name only -->`
- **File:** `<!-- path/to/file -->`
- **Line:** <!-- line number -->
- **Classification:** <!-- from taxonomy -->
- **Storage pattern:** `HARDCODED`
- **Environment:** <!-- which env -->
- **Recommended fix:** Move to vault reference or CI/CD secret. See `secrets-manager` agent for migration plan.
- **Issue filed:** <!-- #issue-number or TBD -->

---

## 5. Environment Coverage Matrix

Which sensitive keys are present in each environment, and how they are stored:

| Key name | Class | dev | staging | prod |
|---|---|---|---|---|
| <!-- API_KEY_STRIPE --> | `API_KEY` | `PLACEHOLDER` | `CI_SECRET_REFERENCED` | `VAULT_REFERENCED` |

**Gaps:** Keys present in prod but missing or unverified in staging/dev indicate potential
environment drift. List them here.

---

## 6. CI/CD Secrets Inventory

| Pipeline file | Secret/variable name | Referenced as | Verified in platform | Notes |
|---|---|---|---|---|
| `.github/workflows/deploy.yml` | <!-- SECRET_NAME --> | `${{ secrets.SECRET_NAME }}` | <!-- yes/no/unknown --> | |

---

## 7. Infrastructure-as-Code Audit

| IaC file | Key name | Storage pattern | Risk | Notes |
|---|---|---|---|---|
| `terraform/main.tf` | <!-- var.db_password --> | <!-- VAULT_REFERENCED --> | 🟢 Good | |

---

## 8. Secrets Manager Reference Inventory

Keys that reference a centralized secrets manager — verify references resolve:

| Key name | Reference type | Resource path | Environment | Verified | Notes |
|---|---|---|---|---|---|
| <!-- DB_CONNSTR --> | Azure Key Vault | `@Microsoft.KeyVault(VaultName=my-vault;SecretName=db-connstr)` | prod | <!-- yes/no --> | |

---

## 9. .gitignore Coverage Assessment

| File pattern | In .gitignore | Finding |
|---|---|---|
| `.env` | <!-- yes/no --> | |
| `.env.local` | <!-- yes/no --> | |
| `*.local.json` | <!-- yes/no --> | |
| `appsettings.Development.json` | <!-- yes/no --> | |
| `terraform.tfvars` | <!-- yes/no --> | |
| `secrets/` | <!-- yes/no --> | |

---

## 10. Recommendations

### Immediate (Critical / High)

1. <!-- Rotate and re-inject key X found hardcoded in file Y -->
2. <!-- Add Z to .gitignore and create a .template companion -->

### Short-term (Medium)

1. <!-- Verify placeholder substitution for keys in environment E -->
2. <!-- Migrate ENV_UNPROTECTED keys to CI secrets or vault references -->

### Long-term

1. <!-- Standardize all environments on vault references -->
2. <!-- Add detect-secrets pre-commit hook to prevent future violations -->

---

## 11. Issues Filed

| Issue | Finding | Severity |
|---|---|---|
| #<!-- number --> | <!-- brief description --> | <!-- Critical/High/Medium --> |

---

## 12. Audit History

| Date | Auditor | Scope | Findings | Status |
|---|---|---|---|---|
| <!-- ISO date --> | <!-- agent/analyst --> | <!-- scope --> | <!-- summary --> | <!-- Open/Closed --> |
