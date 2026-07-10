# Guardrail: OIDC Federation for GitHub Actions → Azure

> **Status:** Mandatory
> **Scope:** All GitHub Actions workflows that authenticate to Azure
> **Issue:** #56

---

## Rule

**All GitHub Actions workflows authenticating to Azure MUST use OpenID Connect (OIDC) federated credentials via `azure/login@v2`.**

Stored service principal credentials (client secrets, client certificates stored as GitHub Secrets) are **forbidden**. Any workflow that uses `AZURE_CLIENT_SECRET` or equivalent stored credential will be rejected in code review and flagged by CI.

---

## How OIDC Works with GitHub Actions + Azure

1. **GitHub mints a short-lived OIDC token** for each workflow run, signed by GitHub's OIDC provider (`token.actions.githubusercontent.com` or enterprise-scoped issuer such as `token.actions.githubusercontent.com/<enterprise-slug>`).
2. **Azure Entra ID validates the token** against a federated credential configured on an app registration (or managed identity). It checks the `issuer`, `subject`, and `audience` claims.
3. **Azure issues a short-lived access token** scoped to the permissions granted to the app registration — no long-lived secret is ever stored or transmitted.

The entire flow is secretless. GitHub never sees an Azure credential, and Azure never stores a GitHub credential.

---

## Bootstrap Pattern

### 1. Create an Entra App Registration

```bash
az ad app create --display-name "basecoat-github-actions"
```

Note the `appId` (this becomes `AZURE_CLIENT_ID`).

### 2. Create a Service Principal

```bash
az ad sp create --id <appId>
```

### 3. Assign Roles

Grant least-privilege RBAC roles on the target subscription or resource group:

```bash
az role assignment create \
  --assignee <appId> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>/resourceGroups/<rg-name>
```

### 4. Add Federated Credentials

Create one federated credential per branch or environment that needs access.

Set an issuer variable first so the credential matches your runtime token:

```bash
# Default issuer:
GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com"

# Enterprise-scoped issuer (if enterprise custom issuer policy is enabled):
# GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com/<enterprise-slug>"

# For the main branch
az ad app federated-credential create --id <appId> --parameters '{
  "name": "main-branch",
  "issuer": "'$GITHUB_OIDC_ISSUER'",
  "subject": "repo:IBuySpy-Shared/basecoat:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For pull requests
az ad app federated-credential create --id <appId> --parameters '{
  "name": "pull-requests",
  "issuer": "'$GITHUB_OIDC_ISSUER'",
  "subject": "repo:IBuySpy-Shared/basecoat:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For a specific environment
az ad app federated-credential create --id <appId> --parameters '{
  "name": "production-env",
  "issuer": "'$GITHUB_OIDC_ISSUER'",
  "subject": "repo:IBuySpy-Shared/basecoat:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### 5. Store IDs as GitHub Secrets

Only **non-secret identifiers** are stored — no passwords or keys:

| GitHub Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App registration Application (client) ID |
| `AZURE_TENANT_ID` | Entra ID (Azure AD) tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |

---

## Example Workflow Step

```yaml
permissions:
  id-token: write   # Required for OIDC token request
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - run: az account show
```

> **Critical:** The `permissions.id-token: write` block is required. Without it, GitHub will not issue the OIDC token and the login step will fail.

---

## Why Client Secrets Are Banned

| Risk | Description |
|---|---|
| **Rotation burden** | Client secrets expire and must be manually rotated. Missed rotations cause outages. |
| **Secret sprawl** | Secrets copied across repos, environments, and developer machines multiply the attack surface. |
| **Exfiltration exposure** | A compromised workflow can exfiltrate a stored secret. OIDC tokens are audience-bound and expire in minutes. |
| **Lateral movement** | A leaked client secret can be used from any network. OIDC tokens are bound to a specific repo, branch, and workflow run. |
| **Audit gap** | Secret usage is hard to attribute. OIDC claims provide exact provenance (repo, branch, commit, actor). |

---

## References

- [Azure: Workload identity federation for GitHub Actions](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-github)
- [GitHub: Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [azure/login action documentation](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended)
