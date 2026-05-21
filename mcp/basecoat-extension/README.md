# BaseCoat Copilot Extension Scaffold

This directory contains the initial `@github/copilot-sdk` scaffold for issue #1075.

## Scope

- Express runtime skeleton for the future BaseCoat Copilot Extension service
- `/health` endpoint for container/app health probes
- `CopilotRuntime` wrapper that initializes `CopilotClient` and exposes a ping path
- Placeholder `/api/copilot/chat` endpoint for follow-up tool wiring

## Commands

```bash
npm install
npm run typecheck
npm run test
npm run start
```

## Endpoints

- `GET /health` — basic runtime liveness payload
- `GET /api/copilot/ping` — checks Copilot SDK connectivity
- `POST /api/copilot/chat` — placeholder (501) until session wiring is implemented

## Alignment

Design source: `docs/design/copilot-extension-prd.md`
Evaluation assets: `mcp/basecoat-extension/evals/intent-routing-golden.yaml`
