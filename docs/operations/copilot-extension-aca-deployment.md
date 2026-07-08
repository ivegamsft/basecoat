# Copilot Extension ACA Deployment Runbook

This runbook covers repository-owned deployment steps for the BaseCoat extension service and lists external prerequisites that cannot be completed from this repository alone.

## Scope

- Build/push `basecoat-extension` image to GHCR
- Deploy/update Azure Container Apps resources via Bicep
- Enable baseline observability (Log Analytics + Application Insights via OpenTelemetry)
- Validate health endpoint and ready revision

## Repository Assets

- Workflow: `.github/workflows/extension-deploy.yml`
- Infrastructure: `infra/extension/main.bicep`
- Param template: `infra/extension/main.bicepparam`
- Container image: `mcp/basecoat-extension/Dockerfile`

## Required Variables and Secrets

Extension deploy authenticates with Azure using the `AZURE_CREDENTIALS` client-secret JSON secret.

| Variable / Secret | Type | Description |
|---|---|---|
| `EXTENSION_AZURE_LOCATION` | repo variable (optional) | Azure region for resource deployment (defaults to `eastus`) |
| `EXTENSION_RESOURCE_GROUP` | secret | Azure resource group containing extension resources (pre-provisioned) |
| `AZURE_CREDENTIALS` | secret | Client-secret JSON credential used by `azure/login` action |

### Required Azure RBAC

The service principal in `AZURE_CREDENTIALS` needs two roles at subscription scope:

| Role | Scope | Purpose |
|---|---|---|
| `Contributor` | `/subscriptions/{id}` | Deploy and update ACA resources via Bicep |
| `User Access Administrator` | `/subscriptions/{id}` | Allow Bicep IaC to create role assignments (e.g. AcrPull for managed identity) |

## Deploy Paths

1. **Automatic on merge to `main`** when extension/infra workflow paths change.
2. **Manual dispatch** of `extension-deploy.yml` with optional `image_tag` and `environment`.

## Validation Checklist

- Workflow run succeeds for build and deploy jobs
- ACA app is in `Running` state with a ready revision
- `GET /health` returns HTTP 200
- Logs are emitted as JSON (`http_request`, `tool_invocation`, `intent_misroute`)
- Application Insights receives traces (for example `copilot.ping` span)

## External Prerequisites (Blockers)

The following remain outside repository-only control and require org/platform admin actions:

1. **GitHub App registration and installation** for the extension (`#1073`, execution tracker `#1127`):
   - Create/install app in `IBuySpy-Shared` org
   - Configure extension endpoint URL to ACA FQDN
   - Configure OAuth callback and credentials
2. **Azure subscription access/approvals** for creating or updating ACA resources and secrets.

Follow admin handoff doc: `docs/operations/COPILOT_EXTENSION_GITHUB_APP_REGISTRATION.md`.

## Post-Deploy Handoff

After deployment, provide to org admins/platform team:

- Extension FQDN (`https://<fqdn>`)
- Health URL (`https://<fqdn>/health`)
- Application Insights component name
- Environment (`prod`, `staging`, or `dev`) and image tag
