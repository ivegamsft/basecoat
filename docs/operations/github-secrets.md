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

### Profile-driven bootstrap matrix

`pwsh scripts/bootstrap.ps1` now evaluates required secrets and variables using
the onboarding profile contract (`solo-dev`, `team-dev`, `regulated-team`).

- Explicit override: `-OnboardingProfile <profile>`
- Contract-driven: `-OnboardingContractPath <path-to-contract-json>`
- Non-interactive CI mode: `-Silent` (fails checks with exact remediation text)

Default profile resolution order:

1. `-OnboardingProfile`
2. `BASECOAT_ONBOARDING_PROFILE`
3. Contract file profile (default `.github/basecoat-onboarding-profile.json`)
4. `team-dev`

| Profile | Workflow pack | Agentic auth secret |
|---|---|---|
| `solo-dev` | `solo` | None; checked-in workflows use `copilot-requests: write` |
| `team-dev` | `team` | None |
| `regulated-team` | `regulated` | `GH_AW_GITHUB_MCP_SERVER_TOKEN` |

Independent of profile, bootstrap also surfaces these secrets/variables whenever
the corresponding workflow file is present in the repo (any profile, including
`solo-dev`):

| Workflow present | Secret/variable required |
|---|---|
| `.github/workflows/publish-to-production.yml` | `PRODUCTION_REPO_TOKEN` |
| `.github/workflows/portal-deploy.yml` (skipped for `solo-dev`) | Portal variables and `GHCR_PULL_TOKEN` |

Bootstrap output includes token rotation/expiration guidance and never writes
plaintext secrets to repository files.

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

**Used by:** Copilot-engine gh-aw workflows compiled without
`permissions: copilot-requests: write`.

**Purpose:** Fallback authentication for repositories that do not use
organization-backed Copilot inference. BaseCoat's checked-in workflows use the
short-lived `${{ github.token }}` through `copilot-requests: write`, so this PAT
is not used for their inference requests.

When organization-backed inference is available, prefer
`copilot-requests: write`; it avoids personal token expiration and bills through
the organization's Copilot subscription. If centralized billing is unavailable,
compile without that permission and configure this secret.

**How to create (recommended):**

1. Go to <https://github.com/settings/personal-access-tokens/new>
2. Create a **fine-grained PAT**
3. Set **Resource owner** to your user account
4. Under **Account permissions**, set **Copilot Requests** → `Read`
5. Set PAT expiration to **30 days or less**
6. Generate token and copy it immediately
7. Run bootstrap script:

```powershell
pwsh scripts/bootstrap-copilot-github-token.ps1 -Repo YOUR-ORG/basecoat
```

If you prefer manual UI setup, add the value as repository secret
`COPILOT_GITHUB_TOKEN`.

**Rotation schedule:** Rotate every 30 days. Set a calendar reminder.
When rotating, generate a new token *before* the old one expires, update
the secret, then revoke the old token.

---

### `GH_AW_GITHUB_TOKEN`

**Used by:** Agentic workflows only when repository operations require a
fine-grained PAT beyond the built-in `GITHUB_TOKEN`.

**Purpose:** Optional override for GitHub API access during agent execution.
BaseCoat's checked-in workflows fall back to the short-lived `GITHUB_TOKEN`.

**How to create:** Use a **separate token** from `COPILOT_GITHUB_TOKEN`
(recommended). Name it `basecoat-gh-aw` and grant only the minimum
repository read permissions required. Set PAT expiration to **30 days or less**.

Do not store a `gho_` OAuth token in this secret. Current gh-aw activation fails
closed when it detects OAuth tokens because they are unsuitable for automation.

Before syncing gh-aw v0.85.4 locks into an organization-backed repository,
remove obsolete OAuth values even if the new inference path will ignore them:

```powershell
gh secret delete COPILOT_GITHUB_TOKEN --repo OWNER/REPO
gh secret delete GH_AW_GITHUB_TOKEN --repo OWNER/REPO
```

Only recreate either secret as a fine-grained PAT when the repository still
needs the documented fallback or expanded GitHub API access.

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

**RBAC prerequisite for the identity referenced by `AZURE_CLIENT_ID`:**

- Subscription scope access to create the target resource group (`Microsoft.Resources/subscriptions/resourcegroups/write`), or the target group must be pre-provisioned.
- Contributor (recommended) on the target portal resource group, or equivalent custom permissions including:
  - `Microsoft.Resources/deployments/validate/action`
  - `Microsoft.Resources/deployments/write`
  - `Microsoft.ContainerRegistry/registries/*`

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

### `PRODUCTION_REPO_TOKEN`

**Used by:** `.github/workflows/publish-to-production.yml`,
`.github/workflows/docs-production.yml`, `.github/workflows/close-production-issues.yml`

**Purpose:** Authorizes the publish-to-production workflow to push release
tags and the `main` branch from the source repository (`YOUR-ORG/basecoat`)
to the production repository (`PRODUCTION-ORG/basecoat`). Without this secret
the workflow fails immediately on any version tag push or manual dispatch.

The production hygiene workflow uses the same token for explicit mirror
cleanup. It accepts comma-separated issue numbers, PR numbers, and exact
branch names. Always preview the plan first; `dry_run` defaults to `true`.

```bash
gh workflow run close-production-issues.yml \
  --repo YOUR-ORG/basecoat \
  -f issue_numbers='221,220' \
  -f pr_numbers='228,227' \
  -f branch_names='automation/token-inventory' \
  -f dry_run=true
```

After reviewing the dry-run log, repeat with `-f dry_run=false`. The workflow
rejects malformed or duplicate numbers, wildcard or empty branch values,
`refs/heads/*` inputs, and protected `main` or `gh-pages` branches. It comments
before closing issues or automation PRs and deletes only explicitly named refs.

**How to create:**

1. Sign in to <https://github.com> as the production repository owner account
2. Go to **Settings → Developer settings → Fine-grained tokens → Generate new token**
3. Set **Resource owner** to `PRODUCTION-ORG`
4. Set **Repository access** to `Only select repositories` → `PRODUCTION-ORG/basecoat`
5. Under **Repository permissions**, grant:
   - **Contents**: Read and write
   - **Issues**: Read and write
   - **Pull requests**: Read and write
   - **Administration**: Read and write
   - **Workflows**: Read and write
6. Generate the token and copy it immediately
7. Add it as a secret on the internal repository:

```powershell
gh secret set PRODUCTION_REPO_TOKEN --repo YOUR-ORG/basecoat
```

**Verification:**

```bash
gh secret list --repo YOUR-ORG/basecoat | grep PRODUCTION_REPO_TOKEN
```

**Bootstrap check:** Run `pwsh scripts/bootstrap.ps1` — Phase 3 surfaces a
missing token with exact remediation steps. In `-Silent` (CI) mode, the check
emits a warning and skips interactive prompting.

**Rotation schedule:** Rotate when the production PAT expiration approaches.
Set a calendar reminder matching the PAT expiration date. Generate a replacement
token before the old one expires, update the secret, then revoke the old token.

---

## Optional Secrets

### `SLACK_WEBHOOK_URL`

**Used by:** Release notification step (if added in future)

Not currently wired up. Reserve the name if Slack integration is planned.

---

## Agentic Workflow Models

BaseCoat's checked-in gh-aw workflows use static model pins from their workflow
sources. In particular, issue triage and code review pin `gpt-5-mini` and reject
`GH_AW_MODEL_AGENT_COPILOT` and `GH_AW_MODEL_DETECTION_COPILOT` overrides in
contract tests. To change a model, update the source, recompile its lock, and run
the workflow contract tests. Do not configure those repository variables for
these workflows.

---

## Validating Secrets

After setting all secrets, trigger a manual workflow run to confirm:

```bash
gh workflow run issue-triage.lock.yml --repo YOUR-ORG/basecoat
```

Check the Actions tab for green status on the `triage` job. If it fails with
`secret not found`, verify the secret name matches exactly (case-sensitive).

---

## See Also

- [Operational Runbook](operational-runbook.md)
- [Enterprise Security Hardening](enterprise-security-hardening.md)
- [GitHub Agentic Workflows docs](https://github.github.com/gh-aw/introduction/overview/)
