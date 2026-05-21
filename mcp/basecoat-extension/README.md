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

## Configuration

The Extension backend reads configuration from environment variables. All OAuth-related variables are required in production.

### GitHub App Credentials

| Variable | Required | Description |
|---|---|---|
| `BASECOAT_EXTENSION_GITHUB_APP_ID` | Yes | GitHub App ID (from app registration) |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_ID` | Yes | GitHub OAuth client ID |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET` | Yes | GitHub OAuth client secret (vault-managed) |
| `BASECOAT_EXTENSION_WEBHOOK_SECRET` | Yes | Webhook signature secret (vault-managed) |
| `BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY` | Yes | GitHub App private key in PEM format (vault-managed) |

### OAuth & Session Tuning

| Variable | Default | Description |
|---|---|---|
| `BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS` | `600000` | State token TTL (10 minutes) |
| `BASECOAT_EXTENSION_SESSION_TTL_MS` | `86400000` | User session TTL (24 hours) |
| `BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS` | `14400000` | Key rotation interval (4 hours) |
| `BASECOAT_EXTENSION_ALLOWED_ORG` | `IBuySpy-Shared` | GitHub org for membership check |
| `BASECOAT_EXTENSION_OAUTH_CALLBACK_URL` | (auto-inferred) | Explicit callback URL (production use) |

### Rate Limiting

| Variable | Default | Description |
|---|---|---|
| `RATE_LIMIT_MAX_REQUESTS` | `10` | Max requests per user per window for `/api/copilot/*` |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Rate-limit window size in milliseconds |

### Other Options

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | HTTP server port |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | (unset) | Enables Azure Monitor OpenTelemetry export when provided |
| `BASECOAT_REPO_ROOT` | (auto-detected) | Explicit repository root for write-tool operations |

### Example `.env.local`

```bash
# Required: GitHub App credentials
BASECOAT_EXTENSION_GITHUB_APP_ID=123456
BASECOAT_EXTENSION_GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BASECOAT_EXTENSION_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----"

# Optional: OAuth & session tuning
BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS=600000
BASECOAT_EXTENSION_SESSION_TTL_MS=86400000
BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS=14400000
BASECOAT_EXTENSION_ALLOWED_ORG=IBuySpy-Shared
BASECOAT_EXTENSION_OAUTH_CALLBACK_URL=https://extension.basecoat.dev/api/github/oauth/callback

# Observability
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...
```

## OAuth Setup

The Extension uses GitHub OAuth 2.0 to authenticate users and authorize API operations. See the full OAuth flow documentation for implementation details and troubleshooting.

### Prerequisites

1. Register a GitHub App for the Extension (runbook: `docs/operations/COPILOT_EXTENSION_GITHUB_APP_REGISTRATION.md`)
2. Install the app on the `IBuySpy-Shared` org
3. Store app credentials in vault (see Configuration section above)

### OAuth Flow Overview

```
User initiates auth
    ↓
Generate state token (CSRF protection)
    ↓
Redirect to GitHub authorization
    ↓
User approves scope
    ↓
GitHub redirects to callback URL with code + state
    ↓
Validate state token (must exist and not expired)
    ↓
Exchange code for access token
    ↓
Fetch user info and verify org membership
    ↓
Create user session (24h TTL)
    ↓
Return session cookie (HttpOnly, Secure, SameSite=Strict)
```

### Endpoints

- `GET /api/github/oauth/authorize` — Initiate OAuth flow (generates state token)
- `GET /api/github/oauth/callback` — Callback handler (validates state, exchanges code, creates session)
- `POST /api/github/session/rotate` — Rotate session token (refresh access token with GitHub)
- `POST /api/github/session/logout` — Logout and invalidate session

### Key Features

- **CSRF Protection**: Random 32+ byte state tokens with 10-minute TTL
- **Org Scoping**: All sessions verify user is member of configured org
- **Key Rotation**: Access tokens rotated every 4 hours (automatic background job)
- **Rate Limiting**: OAuth routes protected at 5-10 req/min per IP/session
- **Error Handling**: Detailed error responses for invalid state, expired sessions, API failures

**Full specification**: `docs/operations/COPILOT_EXTENSION_OAUTH_FLOW.md`


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
