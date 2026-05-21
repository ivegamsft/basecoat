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

## Follow-on work

- #1129 MCP proxy routes
- #1130 OAuth middleware guardrails aligned to #1073 blocker
