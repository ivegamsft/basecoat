# Base Coat Metrics MCP Server

An [MCP](https://modelcontextprotocol.io/) server that exposes Base Coat adoption
metrics to AI agents via the Model Context Protocol. Data is read from the live
GitHub Pages endpoint or a local directory override.

## Tools

| Tool | Description |
|---|---|
| `get-latest-metrics` | Current snapshot (latest/now/refresh snapshot) — Copilot usage, PR cycle times, CI rates, coverage |
| `get-history` | Historical snapshots for the last N weeks (trend/over-time analysis) |
| `get-alerts` | Active degradation alerts only (warnings, regressions, incidents) |
| `get-repo-metrics` | Detailed metrics + trend for a single repository |
| `search-skills` | Find/list skills by name or description keyword |
| `search-agents` | Find/list agents by name or description keyword |
| `get-asset-details` | Return full content of a skill or agent file by relative path (explicit full-file reads) |

> `search-skills`, `search-agents`, and `get-asset-details` require `REPO_DIR` to be set.

## Build

```bash
cd mcp/basecoat-metrics
npm install
npm run build
```

## VS Code / GitHub Copilot CLI Config

Add to your `.vscode/mcp.json` (or user-level MCP config):

```json
{
  "servers": {
    "basecoat-metrics": {
      "type": "stdio",
      "command": "node",
      "args": ["${workspaceFolder}/mcp/basecoat-metrics/dist/index.js"]
    }
  }
}
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MCP_TRANSPORT` | *(none)* | Set to `http` to enable HTTP/SSE transport on `PORT` |
| `NODE_ENV` | *(none)* | Set to `production` to also enable HTTP transport |
| `PORT` | `8080` | Port for HTTP transport |
| `METRICS_BASE_URL` | GitHub Pages URL | Override the base URL for metrics JSON files |
| `METRICS_DIR` | *(none)* | Path to a local directory containing `latest.json`, `history.json`, `alerts.json` |
| `REPO_DIR` | *(none)* | Absolute path to the Base Coat repository root — enables `search-skills`, `search-agents`, and `get-asset-details` |

Set `METRICS_DIR` to `dashboard/metrics` when running locally against a freshly
collected metrics run.

Set `REPO_DIR` to the repository root to enable asset discovery tools. For local use
via VS Code, add it to your `.vscode/mcp.json` `env` block (see below).

## Deployment

The server supports two transports selected by environment variable:

- **`stdio`** (default) — local VS Code / Copilot CLI use
- **`http`** — set `MCP_TRANSPORT=http` or `NODE_ENV=production`

### Docker

```bash
cd mcp/basecoat-metrics
export NPM_REGISTRY="${NPM_REGISTRY:?Set NPM_REGISTRY to your npm registry}"
docker build \
  --build-arg NPM_REGISTRY="${NPM_REGISTRY}" \
  -t basecoat-metrics-mcp .
docker run -p 8080:8080 basecoat-metrics-mcp
# GET http://localhost:8080/health → ok
```

### Azure Container Apps (production)

See [`infra/mcp/README.md`](../../infra/mcp/README.md) for full provisioning steps.

CI/CD:

- **`mcp-build.yml`** — builds and Docker smoke-tests on every PR touching `mcp/**`
- **`mcp-deploy.yml`** — pushes to GHCR and deploys to Azure Container Apps on merge to `main`

Required secrets: `AZURE_CREDENTIALS`, `MCP_RESOURCE_GROUP`
