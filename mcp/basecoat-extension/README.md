# BaseCoat Copilot Extension Scaffold

This directory contains the initial `@github/copilot-sdk` scaffold for issue #1075
and write-tool handlers added for issue #1077.

## Scope

- Express runtime skeleton for the future BaseCoat Copilot Extension service
- `/health` endpoint for container/app health probes
- `CopilotRuntime` wrapper that initializes `CopilotClient` and exposes a ping path
- Placeholder `/api/copilot/chat` endpoint for follow-up tool wiring
- Extension write tool endpoints (`scaffold`, `validate`, `create-pr`) with confirmation handshake
- In-memory per-user rate limiting on `/api/copilot/*` routes (default `10 req/min`)
- OpenTelemetry export support via `APPLICATIONINSIGHTS_CONNECTION_STRING`
- Structured JSON logs for request telemetry, tool invocations, and misroutes
- Concrete write-tool handlers for `scaffold`, `validate`, and `create-pr`
- Two-step confirmation semantics for every write operation

## Commands

```bash
npm install
npm run typecheck
npm run test
npm run start
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | HTTP server port |
| `RATE_LIMIT_MAX_REQUESTS` | `10` | Max requests per user per window for `/api/copilot/*` |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Rate-limit window size in milliseconds |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | *(unset)* | Enables Azure Monitor OpenTelemetry export when provided |
| `BASECOAT_REPO_ROOT` | *(auto-detected)* | Explicit repository root for write-tool operations |

## Endpoints

- `GET /health` — basic runtime liveness payload
- `GET /api/copilot/ping` — checks Copilot SDK connectivity
- `POST /api/copilot/chat` — placeholder (501) until session wiring is implemented
- `POST /api/copilot/tools/:toolName` — extension write tooling endpoint

## Deployment

- Docker image: `mcp/basecoat-extension/Dockerfile`
- ACA IaC: `infra/extension/main.bicep`
- GitHub Actions deploy: `.github/workflows/extension-deploy.yml`
- Runbook and external handoff: `docs/operations/COPILOT_EXTENSION_ACA_DEPLOYMENT.md`
- `POST /api/copilot/tools/:toolName` — write tools (`scaffold`, `validate`, `create-pr`)

## Write tool contracts

All write tools use a safe two-step flow:

1. Call tool without `confirm` to get `status: "needs_confirmation"` and `confirmationToken`
2. Re-send the same payload with `confirm: true` and matching `confirmationToken`

If token mismatches or payload changes, the request fails with `errorCode: "confirmation_mismatch"`.

### `scaffold`

Input:

```json
{
  "assetType": "agent|skill|instruction|prompt",
  "name": "my asset name",
  "description": "optional",
  "confirm": false
}
```

Preview returns generated file path/content. Confirmed execution writes scaffolded files.

### `validate`

Input:

```json
{
  "scope": "full|structure",
  "confirm": false
}
```

`structure` runs `scripts/validate-basecoat.ps1`. `full` runs structure validation plus `tests/run-tests.ps1`.

### `create-pr`

Input:

```json
{
  "title": "PR title",
  "body": "PR body",
  "headBranch": "feat/my-branch",
  "baseBranch": "main",
  "draft": false,
  "confirm": false
}
```

Execution is intentionally blocked unless `BASECOAT_EXTENSION_ENABLE_PR_WRITES=true`.
Without that flag, confirmed requests return `status: "blocked"` with blocker details tied to issue #1073.

## Alignment

Design source: `docs/design/copilot-extension-prd.md`
Evaluation assets: `mcp/basecoat-extension/evals/intent-routing-golden.yaml`
