---
description: "Config file safety instructions. Apply before creating, modifying, or staging any configuration file. Ensures secrets stay out of source control."
applyTo: "**/*"
priority: 2
---

# Config File Safety Instructions

Apply these instructions whenever you are about to create, edit, or stage a configuration file of any kind.

## Before Creating a Config File

1. **Check for secrets.** Does the file contain or will it contain any of the following?
   - Tenant IDs, Client IDs, App IDs, or Object IDs (GUIDs tied to real environments)
   - API keys, bearer tokens, SAS tokens, subscription keys
   - Connection strings (database, storage, Redis, Service Bus)
   - Passwords or shared secrets
   - Personal aliases, email addresses, or UPNs
   - URLs with embedded credentials
   - Aliases arrays (lists of user identifiers)

   If **yes** → the live file must be gitignored. Continue to step 2.

2. **Always create a `.template` companion.**
   - Name it `<filename>.template.<ext>` or `<name>.template.json` (e.g., `config/settings.template.json`).
   - Replace every secret or environment-specific value with a `<PLACEHOLDER>` token (e.g., `<AZURE_TENANT_ID>`).
   - Commit only the `.template` file. Never commit the live file.

3. **Verify `.gitignore` coverage.** Before staging, confirm that the live config file is covered by `.gitignore`:
   - `config/settings.json`
   - `config/settings.local.json`
   - `.env`
   - `.env.local`
   - `*.local.json`

   If the live file is NOT listed — add it to `.gitignore` and verify with `git check-ignore -v <filepath>` before staging anything else.

## When Staging Files

4. **Run a pre-stage secret check.** Before `git add`, scan for the following patterns in files you are about to stage:
   - UUIDs/GUIDs matching the pattern `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` in config values
   - Keys named: `tenantId`, `clientId`, `clientSecret`, `apiKey`, `password`, `token`, `connectionString`, `secret`, `subscriptionId`
   - Values that are not `<PLACEHOLDER>` tokens next to those keys
   - `aliases` arrays containing `@`-email addresses or short strings that look like UPNs

5. **STOP and alert on secret-looking values.**
   If any staged file contains a value that looks like a secret (non-placeholder beside a secret-keyed field):
   - **DO NOT proceed with the commit.**
   - Alert the user immediately:
     ```
     ⛔ SECRET DETECTED — Staging halted.
     File: <path/to/file>
     Field: <field name>
     Action required: Remove the secret value, add the file to .gitignore, and create a .template companion.
     ```
   - Recommend: unstage the file (`git restore --staged <file>`), add to `.gitignore`, and create the template.

## Template File Rules

- Template files (`*.template.json`, `settings.template.json`, etc.) **are** safe to commit — they must contain only `<PLACEHOLDER>` tokens for secrets.
- Non-secret defaults (numbers, booleans, URLs without credentials, feature flags) may have real values in templates.
- Document each placeholder in a comment block or companion README so developers know what to fill in.

## Gitignore Minimum Standard

Every repository must include these entries in `.gitignore`:

```gitignore
# Local config — never commit
config/settings.json
config/settings.local.json
.env
.env.local
*.local.json
```

## Reference

- `docs/CONFIG_PATTERN.md` — full local config pattern documentation
- `agents/config-auditor.agent.md` — scan a repo for secret violations
- `docs/templates/GITIGNORE_TEMPLATE.md` — standard gitignore entries
