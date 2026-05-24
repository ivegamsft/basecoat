# Copilot Extension Infrastructure — Azure Container Apps

Deploys the `basecoat-extension` service to Azure Container Apps with:

- Log Analytics workspace for container and platform logs
- Application Insights for OpenTelemetry traces/metrics
- HTTPS ingress with `/health` probe
- Scale-to-zero and configurable request rate limiting

## Repository Assets

- Workflow: `.github/workflows/extension-deploy.yml`
- Infrastructure: `infra/extension/main.bicep`
- Param template: `infra/extension/main.bicepparam`
- Runtime image: `mcp/basecoat-extension/Dockerfile`

## Required Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Service principal credentials for Azure deployment |
| `EXTENSION_RESOURCE_GROUP` | Azure resource group for extension resources |

## Deploy

```bash
az deployment group create \
  --resource-group <rg> \
  --template-file infra/extension/main.bicep \
  --parameters imageTag=latest imageRepo=<org>/basecoat-extension
```

## External Follow-up

End-to-end extension activation still depends on GitHub App admin actions tracked by issue #1073 (execution checklist in #1127):

1. Org admin creates/installs the extension GitHub App
2. Platform engineer sets extension endpoint + OAuth callback to deployed FQDN
3. Maintainer verifies `@basecoat` invocation in Copilot Chat

See `docs/operations/COPILOT_EXTENSION_GITHUB_APP_REGISTRATION.md`.
