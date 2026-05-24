# BaseCoat Copilot Extension Scaffold

Minimal Sprint 32 scaffold for the BaseCoat Copilot Extension service.

## What is included

- Node.js service entrypoint
- `/healthz` endpoint for local smoke checks
- Placeholder route group for extension APIs
- `@github/copilot-sdk` dependency wiring in `package.json`

## Local run

```bash
cd extensions/basecoat-copilot-extension
npm install
npm start
```

Default port is `3000` (override with `PORT`).

## Smoke check

```bash
curl http://localhost:3000/healthz
```

Expected response:

```json
{"status":"ok","service":"basecoat-copilot-extension"}
```

## MCP proxy routes

Implemented for #1129:

- `POST /api/extension/search` → proxies `search-skills` / `search-agents`
- `GET /api/extension/metrics` → proxies `get-latest-metrics`, `get-history`,
  `get-alerts`, `get-repo-metrics`
- `POST /api/extension/details` → proxies `get-asset-details`

See integration contract:
`docs/integrations/copilot-extension-mcp-proxy.md`

## Remaining follow-on work

- #1130 OAuth middleware guardrails aligned to #1073 blocker
