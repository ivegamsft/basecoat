# GitHub Repository Secrets Setup

This document describes every secret that must be configured in repository
settings for Base Coat's GitHub Actions workflows to run correctly.

Navigate to: **Settings → Secrets and variables → Actions → New repository secret**

---

## Bootstrap Audit Logging

The bootstrap script generates a structured audit log at `.memory/bootstrap-audit.json` with all checks, warnings, and errors found during setup. This log includes:

- **Timestamp** of bootstrap run
- **Pass/fail counts** for all validation checks  
- **Detailed check results** (label, status, details)
- **Warnings and errors** lists for issue tracking

### Creating GitHub issues for critical errors

Run with `-CreateIssues` flag to automatically open a GitHub issue when critical validation errors are found:

```powershell
pwsh scripts/bootstrap.ps1 -CreateIssues
```

This is useful for team adoption: each bootstrap run can surface issues requiring attention without manual reporting. The `-CreateIssues` flag is disabled in `-Silent` mode (CI use) to avoid spam.

---

## Required Secrets

### Portal deploy bootstrap order (staging)

Use this order to avoid mixed bootstrap/deploy failures:

1. Run `pwsh scripts/bootstrap.ps1` in the repo.
   - This is the correct bootstrap for BaseCoat repo operations and portal deploy readiness.
   - Do not substitute `scripts/bootstrap-basecoat.ps1` (consumer-repo adoption) or `scripts/bootstrap-dashboard.ps1` (adoption dashboard setup).
2. Keep Azure CLI logged in and rerun `pwsh scripts/bootstrap.ps1` to auto-provision the portal OIDC app registration and repo variables when missing.
3. Set `GHCR_PULL_TOKEN` at repo scope or `staging` environment scope.
4. Re-run `pwsh scripts/bootstrap.ps1` and verify Phase 3 passes portal OIDC checks.
5. Trigger `.github/workflows/portal-deploy.yml`.

The deploy workflow now fails fast in the `Validate deployment secrets` step when required portal variables are missing or malformed. The bootstrap script can auto-generate the Azure app registration, federated credential, and repo variables from the current Azure CLI session, but the GHCR pull token still requires a manually created PAT with `read:packages` and expiration set to 30 days or less.

---

### `COPILOT_GITHUB_TOKEN`

**Used by:** `issue-triage.lock.yml`, `code-review-agent.lock.yml`,
`security-analyst.lock.yml`, `retro-facilitator.lock.yml`,
`self-healing-ci.lock.yml`, `release-impact-advisor.lock.yml`

**Purpose:** Authenticates the GitHub Agentic Workflow (gh-aw) agent containers.
Without this secret the agentic lock-file workflows will fail to start.

**How to create (recommended):**

1. Go to <https://github.com/settings/personal-access-tokens/new>
2. Create a **fine-grained PAT**
3. Set **Resource owner** to your user account
4. Under **Account permissions**, set **Copilot Requests** → `Read`
5. Set PAT expiration to **30 days or less**
6. Generate token and copy it immediately
7. Run bootstrap script:

```powershell
pwsh scripts/bootstrap-copilot-github-token.ps1 -Repo IBuySpy-Shared/basecoat
```

If you prefer manual UI setup, add the value as repository secret
`COPILOT_GITHUB_TOKEN`.

**Rotation schedule:** Rotate every 30 days. Set a calendar reminder.
When rotating, generate a new token *before* the old one expires, update
the secret, then revoke the old token.

---

### `GH_AW_GITHUB_TOKEN`

**Used by:** All `*.lock.yml` agentic workflow files

**Purpose:** Grants the agentic workflow read access to repository contents
during agent execution (separate from `COPILOT_GITHUB_TOKEN` for least-privilege
isolation).

**How to create:** Use a **separate token** from `COPILOT_GITHUB_TOKEN`
(recommended). Name it `basecoat-gh-aw` and grant only the minimum
repository read permissions required. Set PAT expiration to **30 days or less**.

---

### `GH_AW_GITHUB_MCP_SERVER_TOKEN`

**Used by:** `issue-triage.lock.yml`, `code-review-agent.lock.yml`

**Purpose:** Authenticates the GitHub MCP server sidecar used by the gh-aw
agent to call GitHub APIs from within the agent container.

**How to create:** A fine-grained PAT scoped to this repository with:

- **Repository permissions:** Issues (read/write), Pull requests (read/write),
  Contents (read)
- Name it `basecoat-mcp-server`
- Set PAT expiration to **30 days or less**

---

### `STAGING_API_TOKEN`

**Used by:** `performance-baseline-pr-check.yml`

**Purpose:** API token for the staging deployment used by k6 performance tests.

**Note:** This workflow is a pre-existing non-blocking failure when the staging
deployment is not provisioned. CI will report it as failing on every PR; this
does not block merges since branch protection is not enforced on `main`.

---

### `AZURE_CLIENT_ID`

**Used by:** `.github/workflows/portal-deploy.yml`

**Purpose:** OIDC client ID for the portal deploy app registration.

### `AZURE_TENANT_ID`

**Used by:** `.github/workflows/portal-deploy.yml`

**Purpose:** Entra tenant ID for Azure login.

### `AZURE_SUBSCRIPTION_ID`

**Used by:** `.github/workflows/portal-deploy.yml`

**Purpose:** Target Azure subscription for portal staging deployment.

---

### `PORTAL_POSTGRES_ADMIN_PASSWORD`

**Used by:** `.github/workflows/portal-deploy.yml`

**Purpose:** Optional override for PostgreSQL admin password.

If omitted, `portal/app/iac/main.bicep` generates a secure password per deployment.

---

### `GHCR_PULL_TOKEN`

**Used by:** `.github/workflows/portal-deploy.yml`

**Purpose:** Allows Container Apps runtime to pull private images from GHCR.

**Required scope:** `read:packages`

Set PAT expiration to **30 days or less** and rotate monthly.

This is deployment/runtime specific (not just build-time): `GITHUB_TOKEN` can push images during workflow execution, but Azure Container Apps needs a separate credential to pull private GHCR images after deployment.

---

## Optional Secrets

### `SLACK_WEBHOOK_URL`

**Used by:** Release notification step (if added in future)

Not currently wired up. Reserve the name if Slack integration is planned.

---

## Validating Secrets

After setting all secrets, trigger a manual workflow run to confirm:

```bash
gh workflow run issue-triage.lock.yml --repo IBuySpy-Shared/basecoat
```

Check the Actions tab for green status on the `triage` job. If it fails with
`secret not found`, verify the secret name matches exactly (case-sensitive).

---

## See Also

- [Operational Runbook](OPERATIONAL_RUNBOOK.md)
- [Enterprise Security Hardening](ENTERPRISE_SECURITY_HARDENING.md)
- [GitHub Agentic Workflows docs](https://github.github.com/gh-aw/introduction/overview/)
