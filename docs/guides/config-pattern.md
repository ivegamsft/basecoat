# Local Config Pattern

This document defines the standard pattern for managing local configuration files in a basecoat-based repository. The goal is to keep secrets, personal identifiers, and environment-specific values **out of source control**, while ensuring every developer can onboard quickly from a committed template.

---

## File Roles

| File | Committed | Purpose |
|------|-----------|---------|
| `config/settings.template.json` | ✅ Yes | Source-of-truth shape with `<PLACEHOLDER>` values. All developers start here. |
| `config/settings.json` | ❌ No (gitignored) | Developer's local copy, populated from the template. Never committed. |
| `config/settings.local.json` | ❌ No (gitignored) | Local override layer — developer-specific tweaks on top of `settings.json`. |
| `.env` | ❌ No (gitignored) | Environment variable file for runtime secrets (Node.js, Python, etc.). |
| `.env.local` | ❌ No (gitignored) | Local override for `.env` values. |

---

## What NEVER Goes in Source Control

The following categories of values must **never** appear in a committed file:

- **Tenant IDs** — `tenantId`, `tenant_id`, `TenantId`, or Azure AD tenant GUIDs
- **Client IDs / App IDs** — `clientId`, `appId`, `applicationId`, or service principal GUIDs
- **API keys and tokens** — any bearer token, subscription key, SAS token, or shared secret
- **Connection strings** — database URIs, storage account connection strings, Redis URLs with credentials
- **Personal aliases** — developer usernames, email addresses, UPNs in any config field
- **GUIDs tied to specific environments** — resource IDs, subscription IDs, object IDs of real Azure resources
- **URLs with embedded credentials** — `<REDACTED_URL_WITH_CREDENTIALS>`
- **Aliases arrays** — lists of UPNs or email addresses used for routing or notifications
- **Passwords and secrets of any kind** — including test/dev passwords

> **Rule:** If the value is specific to a person, environment, or subscription, it is a secret — gitignore it.

---

## Onboarding Pattern

```text
# 1. Copy the template to your local config
cp config/settings.template.json config/settings.json

# 2. Fill in your real values
#    (use your editor, Azure Key Vault CLI, or a provisioning script)

# 3. Optionally create a local override
cp config/settings.json config/settings.local.json
```

Your application should load in priority order:

1. `config/settings.local.json` (if present)
2. `config/settings.json`
3. Environment variables (`.env.local` → `.env`)
4. Defaults baked into code (non-secret values only)

---

## Template File Convention

Every config file with real values must have a committed `.template` sibling. The template must use `<PLACEHOLDER>` tokens for every secret or environment-specific field.

### Example: `config/settings.template.json`

```json
{
  "azure": {
    "tenantId": "<AZURE_TENANT_ID>",
    "clientId": "<AZURE_CLIENT_ID>",
    "clientSecret": "<AZURE_CLIENT_SECRET>",
    "subscriptionId": "<AZURE_SUBSCRIPTION_ID>"
  },
  "database": {
    "connectionString": "<DATABASE_CONNECTION_STRING>",
    "maxConnections": 10
  },
  "api": {
    "baseUrl": "<API_BASE_URL>",
    "apiKey": "<API_KEY>",
    "timeoutMs": 30000
  },
  "notifications": {
    "aliases": ["<USER_ALIAS_1>", "<USER_ALIAS_2>"],
    "smtpHost": "<SMTP_HOST>"
  }
}
```

Non-secret defaults (numbers, booleans, feature flags with safe defaults) **may** have real values in the template.

---

## Framework-Agnostic Usage

### PowerShell

```powershell
$settings = Get-Content config/settings.json | ConvertFrom-Json
$tenantId = $settings.azure.tenantId
```

### Node.js

```javascript
import { readFileSync } from 'fs';
const settings = JSON.parse(readFileSync('config/settings.json', 'utf-8'));
// Or use dotenv for .env files:
import 'dotenv/config';
const tenantId = process.env.AZURE_TENANT_ID;
```

### Python

```python
import json, os
from dotenv import load_dotenv

load_dotenv('.env.local')
load_dotenv('.env')

with open('config/settings.json') as f:
    settings = json.load(f)

tenant_id = os.getenv('AZURE_TENANT_ID', settings['azure']['tenantId'])
```

---

## CI/CD

In pipelines, inject secrets via environment variables from a secrets store (e.g., Azure Key Vault, GitHub Actions Secrets, Azure Pipelines variable groups). **Never** check in a populated `settings.json` for CI purposes.

```yaml
# GitHub Actions example
- name: Run app
  env:
    AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
```

---

## Enforcement

- `.gitignore` must cover `config/settings.json`, `config/settings.local.json`, `.env`, `.env.local`, and `*.local.json`.
- The `config-auditor` agent (`agents/basecoat-50-security-config-auditor.agent.md`) can scan a repo for violations.
- The pre-commit hook (`scripts/install-git-hooks.sh`) blocks common secret patterns.
- See `docs/templates/gitignore-template.md` for the standard gitignore entries.

---

## Related

- `instructions/basecoat-10-core-config.instructions.md` — agent instructions for config file handling
- `agents/basecoat-50-security-config-auditor.agent.md` — automated config secret scanner
- `docs/templates/gitignore-template.md` — standard gitignore entries
- `instructions/basecoat-50-security-security.instructions.md` — broader security standards
