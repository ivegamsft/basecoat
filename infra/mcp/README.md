# MCP Server Infrastructure — Azure Container Apps

Provisions the `basecoat-metrics-mcp` server on Azure Container Apps.
The server exposes Base Coat adoption metrics to AI agents over HTTP/MCP.

> **⚠️ Required before deploying:** Two parameters have no org-specific defaults and
> **must** be set explicitly — the placeholders `YOUR_ORG` will cause the deployment to
> fail or point at the wrong data source if left unchanged:
>
> - `imageRepo` — your GHCR image repository, e.g. `myorg/basecoat-metrics-mcp`
> - `metricsBaseUrl` — your GitHub Pages metrics endpoint, e.g. `https://myorg.github.io/basecoat/metrics`
>
> Use `infra/mcp/main.bicepparam` (copy and fill in) or pass them on the CLI as shown below.

## Architecture

```text
GHCR image
  ghcr.io/YOUR_ORG/basecoat-metrics-mcp:latest
           │
           ▼
Azure Container Apps Environment  (bcmcp-env)
  └── Container App  (bcmcp-app)
        ├── Port 8080 → HTTPS ingress (auto-TLS)
        ├── GET /health → 200 ok
        └── MCP tools over HTTP/SSE
           ├── get-latest-metrics
           ├── get-history
           ├── get-alerts
           └── get-repo-metrics
```

Keeps one replica running at all times by default (`minReplicas = 1`).
Azure archives Consumption-tier environments when all apps scale to zero and stay idle — setting `minReplicas = 0` in a long-running environment will eventually trigger archival and require full environment recreation to restore.

## One-Time Setup

Run the bootstrap script. It creates the Azure resource group, provisions a
service principal, and pushes both secrets to GitHub — all idempotent:

```powershell
pwsh scripts/bootstrap-mcp.ps1
```

Preview without making changes:

```powershell
pwsh scripts/bootstrap-mcp.ps1 -DryRun
```

Bootstrap and immediately trigger the first deploy:

```powershell
pwsh scripts/bootstrap-mcp.ps1 -TriggerDeploy
```

Override defaults:

```powershell
pwsh scripts/bootstrap-mcp.ps1 -ResourceGroup rg-mcp-staging -Location westus2
```

The workflow outputs the FQDN. Update `.vscode/mcp.json` with it:

```json
"basecoat-metrics-remote": {
  "type": "http",
  "url": "https://<FQDN>"
}
```

## Manual Deploy

```bash
# Build and push image
cd mcp/basecoat-metrics
IMAGE="ghcr.io/YOUR_ORG/basecoat-metrics-mcp:latest"
docker build -t "${IMAGE}" .
docker push "${IMAGE}"

# Deploy Bicep
az deployment group create \
  --resource-group rg-basecoat-mcp \
  --template-file infra/mcp/main.bicep \
  --parameters imageTag=latest \
    imageRepo=YOUR_ORG/basecoat-metrics-mcp \
    metricsBaseUrl=https://YOUR_ORG.github.io/basecoat/metrics
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `location` | RG location | Azure region |
| `environment` | `prod` | `prod`, `staging`, or `dev` |
| `imageTag` | `latest` | Container image tag |
| `imageRepo` | *(required — no safe default)* | GHCR repo, e.g. `YOUR_ORG/basecoat-metrics-mcp` |
| `metricsBaseUrl` | *(required — no safe default)* | GitHub Pages metrics URL, e.g. `https://YOUR_ORG.github.io/basecoat/metrics` |
| `cpuCores` | `0.25` | vCPU per replica |
| `memoryGi` | `0.5` | Memory per replica |
| `minReplicas` | `1` | Minimum replicas; keep at `1` to prevent environment archival. Only set to `0` for disposable dev environments you can afford to recreate. |
| `maxReplicas` | `3` | Max replicas under load |

## Outputs

| Output | Description |
|---|---|
| `fqdn` | Fully-qualified domain name |
| `healthUrl` | `GET /health` → 200 |
| `mcpUrl` | MCP endpoint for `.vscode/mcp.json` |

## Required Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Service principal JSON from `az ad sp create-for-rbac --sdk-auth` |
| `MCP_RESOURCE_GROUP` | Azure resource group name |

## Teardown

```bash
az group delete --name rg-basecoat-mcp --yes
```
