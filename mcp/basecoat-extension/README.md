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

The Extension backend reads configuration from environment variables. Configure one of three authentication modes:

### Auth Mode Selection

| Mode | Env Var | When to Use | Best For |
|------|---------|------------|----------|
| **GitHub App** | `BASECOAT_EXTENSION_GITHUB_APP_ID` + related | User-facing features, user delegation | OAuth, multi-user access |
| **App Token** | `BASECOAT_EXTENSION_GITHUB_TOKEN` | Service account operations | Service-to-service, CI/CD |
| **OIDC** | `BASECOAT_EXTENSION_AUTH_MODE=oidc` | Azure-native deployments | Vault-less, managed identity |

### GitHub App Credentials (Default Mode)

| Variable | Required | Description |
|---|---|---|
| `BASECOAT_EXTENSION_GITHUB_APP_ID` | Yes (for github-app mode) | GitHub App ID (from app registration) |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_ID` | Yes (for github-app mode) | GitHub OAuth client ID |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET` | Yes (for github-app mode) | GitHub OAuth client secret (vault-managed) |
| `BASECOAT_EXTENSION_WEBHOOK_SECRET` | Yes (for github-app mode) | Webhook signature secret (vault-managed) |
| `BASECOAT_EXTENSION_PRIVATE_KEY_PEM` | Yes (for github-app mode) | GitHub App private key in PEM format (vault-managed) |

### App Token Credentials (Alternative)

| Variable | Required | Description |
|---|---|---|
| `BASECOAT_EXTENSION_GITHUB_TOKEN` | Yes (for app-token mode) | Personal Access Token or GitHub workflow token |

### OIDC Credentials (Alternative)

| Variable | Required | Description |
|---|---|---|
| `BASECOAT_EXTENSION_AUTH_MODE` | Yes (set to `oidc`) | Enable OIDC mode |
| `AZURE_TENANT_ID` | Yes (for oidc mode) | Azure tenant ID for federated identity |
| `AZURE_CLIENT_ID` | Yes (for oidc mode) | Azure client ID for managed identity |
| `AZURE_FEDERATED_TOKEN_FILE` | Auto (in ACA) | Federated token file (set by Azure Container Apps) |
| `BASECOAT_EXTENSION_APP_ID` | Yes | GitHub App ID (from app registration) |
| `BASECOAT_EXTENSION_CLIENT_ID` | Yes | GitHub OAuth client ID |
| `BASECOAT_EXTENSION_CLIENT_SECRET` | Yes | GitHub OAuth client secret (vault-managed) |
| `BASECOAT_EXTENSION_WEBHOOK_SECRET` | Yes | Webhook signature secret (vault-managed) |
| `BASECOAT_EXTENSION_PRIVATE_KEY_PEM` | Yes | GitHub App private key in PEM format (vault-managed) |

### OAuth & Session Tuning (GitHub App Mode Only)

| Variable | Default | Description |
|---|---|---|
| `BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS` | `600000` | State token TTL (10 minutes) |
| `BASECOAT_EXTENSION_SESSION_TTL_MS` | `86400000` | User session TTL (24 hours) |
| `BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS` | `14400000` | Key rotation interval (4 hours) |
| `BASECOAT_EXTENSION_ALLOWED_ORG` | `IBuySpy-Shared` | GitHub org for membership check |
| `BASECOAT_EXTENSION_OAUTH_CALLBACK_URL` | (auto-inferred) | Explicit callback URL (production use) |
| `BASECOAT_EXTENSION_ENABLE_OAUTH_TOKEN_EXCHANGE_STUB` | (unset) | Enables temporary callback stub response only when explicitly set to `true` while live token exchange remains blocked by #1073 |

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

#### Option 1: GitHub App (User-Delegated OAuth)

```bash
# GitHub App credentials
BASECOAT_EXTENSION_GITHUB_APP_ID=123456
BASECOAT_EXTENSION_GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Required: GitHub App credentials
BASECOAT_EXTENSION_APP_ID=123456
BASECOAT_EXTENSION_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
BASECOAT_EXTENSION_CLIENT_SECRET=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BASECOAT_EXTENSION_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
BASECOAT_EXTENSION_PRIVATE_KEY_PEM="-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----"

# Optional: OAuth & session tuning
BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS=600000
BASECOAT_EXTENSION_SESSION_TTL_MS=86400000
BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS=14400000
BASECOAT_EXTENSION_ALLOWED_ORG=IBuySpy-Shared
BASECOAT_EXTENSION_OAUTH_CALLBACK_URL=https://extension.basecoat.dev/api/github/oauth/callback
```

#### Option 2: App Token (Service Account)

```bash
# App Token mode (simpler setup, no user delegation)
BASECOAT_EXTENSION_AUTH_MODE=app-token
BASECOAT_EXTENSION_GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Or use workflow token in CI/CD:
# BASECOAT_EXTENSION_GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
```

#### Option 3: OIDC (Azure Managed Identity)

```bash
# OIDC mode (vault-less, Azure-native)
BASECOAT_EXTENSION_AUTH_MODE=oidc
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# AZURE_FEDERATED_TOKEN_FILE is set automatically in Azure Container Apps
```

#### All modes: Common Options

```bash
# Observability
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...

# Rate Limiting
RATE_LIMIT_MAX_REQUESTS=10
RATE_LIMIT_WINDOW_MS=60000

# Server
PORT=3000

# Optional: Explicit repo root
BASECOAT_REPO_ROOT=/workspace/basecoat
```

## OAuth Setup

The Extension supports three authentication modes. Choose based on your use case:

### GitHub App Registration (Manual Setup) — Required for Mode 1

#### Step 1: Create the GitHub App

Visit: [GitHub App settings](https://github.com/organizations/IBuySpy-Shared/settings/apps/new)

Fill in the form with:

| Field | Value |
|-------|-------|
| GitHub App name | `BaseCoat Copilot Extension` |
| Homepage URL | `https://github.com/IBuySpy-Shared/basecoat` |
| **User authorization callback URL** | `https://extension.basecoat.dev/api/github/oauth/callback` |
| Webhook → Active | ✅ Check this |
| **Webhook URL** | `https://extension.basecoat.dev/api/github/webhook` |
| Expire user authorization tokens | ✅ Check this |
| Request user authorization (OAuth) during installation | ✅ Check this |
| Enable Device Flow | ✅ Check this |

#### Important URLs

- **`/api/github/oauth/callback`** — OAuth callback (user sign-in)
- **`/api/github/webhook`** — Webhook receiver (app events)
- Replace `extension.basecoat.dev` with your actual deployment URL

#### Step 2: Set Permissions

Expand each section and configure:

#### Repository Permissions

- Contents: Read & write (for PR creation, file scaffolding)
- Metadata: Read-only (always required)

#### Organization Permissions

- Members: Read-only (for org membership verification)

#### Account Permissions

- None required

#### Events to Subscribe To

- Push
- Pull request
- Repository (for branch creation)

#### Step 3: Install on Organization

1. Click "Create GitHub App"
2. On the app details page, click "Install App"
3. Select `IBuySpy-Shared` organization
4. Choose repository access: "All repositories" or select specific repos
5. Authorize installation

#### Step 4: Download Credentials

1. Go to app settings → "Private keys"
2. Generate a new private key → download `.pem` file
3. Note the **App ID** and **Client ID** from the top of the page

#### Step 5: Store Credentials

```bash
export BASECOAT_EXTENSION_GITHUB_APP_ID=<APP_ID>
export BASECOAT_EXTENSION_GITHUB_CLIENT_ID=<CLIENT_ID>
export BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET=<SECRET_from_app_page>
export BASECOAT_EXTENSION_WEBHOOK_SECRET=<generate_a_random_string>
export BASECOAT_EXTENSION_PRIVATE_KEY_PATH=./private-key.pem
./mcp/basecoat-extension/scripts/bootstrap-credentials.ps1
```

### 1. GitHub App (Default) — User-Delegated OAuth

Users grant the extension permission to call GitHub APIs on their behalf.

**Use case:** User-facing features (scaffold assets, create PRs, manage repos)

**Setup:**

See "GitHub App Registration (Manual Setup)" section above for step-by-step instructions on creating and configuring the app.

Then store credentials using the bootstrap script (Step 5 above).

**Features:**

```text
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
Temporary token-exchange stub (feature-flagged)
    ↓
Return blocked-by-#1073 callback payload for follow-up validation
```

**Endpoints:**

- `GET /api/github/oauth/request` — Initiate OAuth flow (generates state token)
- `GET /api/github/oauth/callback` — Callback handler with middleware guardrails and temporary token-exchange stub

**Features:**

- CSRF Protection: Random 32+ byte state tokens with 10-minute TTL
- Org Scoping: All sessions verify user is member of configured org
- Key Rotation: Access tokens rotated every 4 hours (automatic background job)
- Rate Limiting: OAuth routes protected at 5-10 req/min per IP/session
- Error Handling: Detailed error responses for invalid state, expired sessions, API failures

**Full specification:** `docs/operations/COPILOT_EXTENSION_OAUTH_FLOW.md`
**Request-flow diagram:** [docs/diagrams/copilot-extension-oauth-and-tool-invocation-flow.md](../../docs/diagrams/copilot-extension-oauth-and-tool-invocation-flow.md)

### 2. App Token — Service Account

Extension uses a fixed GitHub token (Personal Access Token or workflow token) for all API operations.

**Use case:** Service-to-service automation (org-wide operations, CI/CD integration)

**Setup:**

```bash
export BASECOAT_EXTENSION_AUTH_MODE=app-token
export BASECOAT_EXTENSION_GITHUB_TOKEN=ghp_xxxx... # or github_pat_xxxx...
./mcp/basecoat-extension/scripts/bootstrap-credentials.ps1
```

**Limitations:**

- Single service account identity (not user-delegated)
- All operations attributed to the token issuer
- No per-user session isolation
- PAT tokens can be scope-limited (fine-grained) or classic (all-or-nothing)

**Best for:**

- Automated repository management
- Webhook processing
- CI/CD pipeline integration

### 3. OIDC — Azure Managed Identity

Extension obtains GitHub tokens via Azure federated identity (no secrets in vault).

**Use case:** Azure-native deployments with vault-less credential management

**Setup:**

```bash
export BASECOAT_EXTENSION_AUTH_MODE=oidc
export AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# AZURE_FEDERATED_TOKEN_FILE is set automatically in Azure Container Apps
./mcp/basecoat-extension/scripts/bootstrap-credentials.ps1
```

**Requirements:**

- Extension deployed in Azure Container Apps with managed identity
- Azure OIDC provider configured
- GitHub App or PAT authorized via Azure OIDC token exchange

**Features:**

- No secrets stored in vault (tokens issued at runtime)
- Automatic token refresh
- Audit trail via Azure
- **CSRF Protection**: Random 32+ byte state tokens with 10-minute TTL
- **State Guardrails**: OAuth middleware validates callback parameters and state replay/expiry
- **Feature Flag Control**: Callback stub requires `BASECOAT_EXTENSION_ENABLE_OAUTH_TOKEN_EXCHANGE_STUB=true`
- **Blocked Dependency Signaling**: Callback payloads explicitly identify issue #1073 as the live token-exchange blocker
- **Error Handling**: Detailed error responses for invalid state, missing parameters, and disabled stub path

Live OAuth token exchange (GitHub code→token call, org membership check, and session cookie issuance) remains blocked until org-admin registration is completed for issue #1073 (currently tracked through org-admin action in #1127).

## Configuration Priority

## Endpoints

- `GET /health` — basic runtime liveness payload
- `GET /api/copilot/ping` — checks Copilot SDK connectivity
- `POST /api/copilot/chat` — placeholder (501) until session wiring is implemented
- `POST /api/copilot/tools/:toolName` — extension write tooling endpoint
- Request flow reference (OAuth + tools + health/ping): [docs/diagrams/copilot-extension-oauth-and-tool-invocation-flow.md](../../docs/diagrams/copilot-extension-oauth-and-tool-invocation-flow.md)

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
