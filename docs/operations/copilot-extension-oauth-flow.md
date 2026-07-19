# GitHub OAuth and Session Flow for BaseCoat Copilot Extension
<!-- markdownlint-disable -->

This document describes the OAuth 2.0 flow, state validation strategy, session management design, and error handling for the BaseCoat Copilot Extension backend.

## Overview

The BaseCoat Copilot Extension uses GitHub App OAuth to authenticate users and authorize API access. The flow is stateless at the HTTP layer but maintains per-user session state in-memory to track authentication context and validate CSRF tokens.

## OAuth Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ User in Copilot Chat (IDE / github.com / mobile)                   │
└────────────────┬────────────────────────────────────────────────────┘
                 │
                 │ 1. Initiate auth (click "Sign in" or implicit)
                 v
         ┌──────────────────────────────────────────┐
         │ Extension Backend: /api/github/oauth     │
         │ Generate state token + store session     │
         │ Redirect to GitHub OAuth authorize URL  │
         └──────────────────────────────────────────┘
                 │
                 │ 2. state=<random>, session TTL=10m
                 v
    ┌────────────────────────────────────────────────────┐
    │ GitHub Authorization Server                        │
    │ User logs in (if needed), approves scopes          │
    └────────────────────────────────────────────────────┘
                 │
                 │ 3. Redirect back to callback URL
                 │    + code=<auth_code>
                 │    + state=<same_state>
                 v
         ┌──────────────────────────────────────────┐
         │ Extension Backend: /api/github/oauth/    │
         │ callback                                  │
         │ 1. Validate state token (must exist +    │
         │    match + not expired)                  │
         │ 2. Exchange code for access token        │
         │ 3. Fetch user/org info from GitHub API   │
         │ 4. Create session (key rotation + TTL)   │
         │ 5. Return session cookie or token        │
         └──────────────────────────────────────────┘
                 │
                 │ 4. Set cookie or Bearer token
                 │    Delete state token
                 │    session_id=<uuid>, TTL=24h
                 v
         ┌──────────────────────────────────────────┐
         │ Copilot Client                           │
         │ Store session cookie/token               │
         │ Ready to call /api/copilot/* tools       │
         └──────────────────────────────────────────┘
```

## Request-to-State-to-Redirect Flow

### 1. Initiate OAuth Request

**Endpoint**: `GET /api/github/oauth/authorize`

**Request**:
```
GET /api/github/oauth/authorize?redirect_uri=http://localhost:3000/callback HTTP/1.1
Host: extension.basecoat.dev
```

**Response**:
```json
{
  "status": "initiated",
  "authorizationUrl": "https://github.com/login/oauth/authorize?client_id=ABC123&state=xyz789&scope=user:email+read:org&redirect_uri=https://extension.basecoat.dev/api/github/oauth/callback"
}
```

**Backend Actions**:
1. Generate cryptographically secure random `state` token (min 32 bytes, hex-encoded)
2. Create in-memory session entry with:
   - `state`
   - `createdAt: Date.now()`
   - `ttl: 600000` (10 minutes)
   - `nonce: <uuid>` (for double-submit cookie pattern if needed)
3. Return `authorizationUrl` containing:
   - `client_id` (from `BASECOAT_EXTENSION_GITHUB_APP_ID`)
   - `state=<generated>`
   - `scope: user:email read:org` (minimal required)
   - `redirect_uri` matching registered App callback

### 2. GitHub User Authorization

User is directed to GitHub's authorization server. GitHub validates the `client_id`, `redirect_uri`, and `scope`, then presents a consent screen if needed.

Upon approval, GitHub redirects to the registered callback URL with:
- `code=<temporary_auth_code>` (valid for 10 minutes)
- `state=<original_state>` (must match exactly)

### 3. Callback and Code Exchange

**Endpoint**: `POST /api/github/oauth/callback`

**Request**:
```
GET /api/github/oauth/callback?code=abc123def456&state=xyz789 HTTP/1.1
Host: extension.basecoat.dev
```

**Backend Actions**:

1. **Validate state token**:
   - Lookup `state` in session store
   - Verify exists, not expired, and matches incoming `state` parameter
   - If invalid: respond with `400 Bad Request` + destroy any related session
   - If valid: proceed to step 2

2. **Exchange code for access token**:
   ```bash
   POST https://github.com/login/oauth/access_token \
     -H "Accept: application/json" \
     -d client_id=ABC123 \
     -d client_secret=<SECRET> \
     -d code=abc123def456
   ```
   - Response includes `access_token`, `token_type: Bearer`, `scope`
   - Store access token in memory (keyed by session ID, not persistent)

3. **Fetch user/org info**:
   ```bash
   GET https://api.github.com/user \
     -H "Authorization: Bearer <access_token>"
   ```
   - Extract user login, ID, email, organization memberships
   - Verify user is member of allowed org (`IBuySpy-Shared` by default)
   - If not a member: respond with `403 Forbidden`

4. **Create user session**:
   - Generate `session_id` (UUID v4)
   - Store in session store:
     ```
     {
       "session_id": "550e8400-e29b-41d4-a716-446655440000",
       "user_id": "12345678",
       "user_login": "alice",
       "access_token": "<token>",
       "scope": "user:email read:org",
       "created_at": 1634567890000,
       "last_rotated_at": 1634567890000,
       "ttl": 86400000,  // 24 hours
       "rotation_count": 0
     }
     ```
   - Encrypt/sign session token for cookie payload (optional but recommended)

5. **Return session**:
   ```json
   {
     "status": "authenticated",
     "session_id": "550e8400-e29b-41d4-a716-446655440000",
     "user_login": "alice",
     "expires_at": 1634654290000
   }
   ```
   - Set `Set-Cookie` header with `session_id` (HttpOnly, Secure, SameSite=Strict)
   - Or return Bearer token for manual client-side storage
   - Delete `state` token from session store

**Response on Success**:
```
HTTP/1.1 302 Found
Location: http://localhost:3000/chat?session_id=550e8400-e29b-41d4-a716-446655440000
Set-Cookie: session_id=<encrypted>; HttpOnly; Secure; SameSite=Strict; Max-Age=86400
```

## State Param Validation: CSRF Protection & TTL

### State Token Design

- **Length**: 32+ bytes (256 bits)
- **Format**: Random hex string (no structured data embedded)
- **Generation**: `crypto.randomBytes(32).toString('hex')`
- **Storage**: In-memory keyed by state value (not session ID yet)
- **TTL**: 10 minutes (600,000 ms)

### CSRF Protection Strategy

1. **Same-Site Cookies**: All state-sensitive endpoints use `SameSite=Strict` cookies to prevent cross-site request forgery.
2. **Double-Submit Pattern** (optional enhancement):
   - Generate `nonce` alongside `state`
   - Return both in redirect URL
   - Client includes both in callback
   - Backend verifies match
3. **No State Embedding**: State token is random and opaque—no user ID or timestamp baked in. This prevents attacker-controlled state synthesis.

### TTL Enforcement

```javascript
// Pseudocode for state validation
function validateState(incomingState) {
  const storedSession = stateStore.get(incomingState);
  
  if (!storedSession) {
    throw new Error('State not found or already consumed');
  }
  
  const age = Date.now() - storedSession.createdAt;
  if (age > storedSession.ttl) {
    stateStore.delete(incomingState); // Clean up
    throw new Error('State expired (TTL exceeded)');
  }
  
  // State is valid; proceed to code exchange
  return storedSession;
}
```

## Session Store Design

### In-Memory Storage Architecture

The session store is a two-tier hash map:

```javascript
interface SessionStore {
  // Tier 1: state tokens (short-lived, CSRF protection)
  stateTokens: Map<string, {
    createdAt: number,
    ttl: number,
    nonce?: string
  }>,
  
  // Tier 2: authenticated sessions (long-lived, user context)
  userSessions: Map<string, {
    session_id: string,
    user_id: number,
    user_login: string,
    access_token: string,
    scope: string,
    created_at: number,
    last_rotated_at: number,
    ttl: number,
    rotation_count: number
  }>
}
```

### Key Rotation Strategy

1. **When**: Every 4 hours or on explicit rotation request
2. **Trigger**: Background job or `POST /api/github/session/rotate`
3. **Process**:
   ```javascript
   function rotateSessionToken(sessionId) {
     const oldSession = userSessions.get(sessionId);
     if (!oldSession) throw new Error('Session not found');
     
     // Call GitHub API with old token to refresh/validate
     const newToken = await refreshGitHubAccessToken(oldSession.access_token);
     
     // Create new session record
     const newSession = {
       ...oldSession,
       access_token: newToken,
       last_rotated_at: Date.now(),
       rotation_count: oldSession.rotation_count + 1
     };
     
     userSessions.set(sessionId, newSession);
     return newSession;
   }
   ```

4. **Invalidation**: On every rotation, the old token is discarded (not stored in history).

### Session Cleanup

```javascript
// Run every 5 minutes
function cleanupExpiredSessions() {
  const now = Date.now();
  
  for (const [stateToken, metadata] of stateTokens.entries()) {
    if (now - metadata.createdAt > metadata.ttl) {
      stateTokens.delete(stateToken);
    }
  }
  
  for (const [sessionId, session] of userSessions.entries()) {
    if (now - session.created_at > session.ttl) {
      userSessions.delete(sessionId);
    }
  }
}
```

### Persistence Notes

- **Development**: In-memory only (stateless)
- **Production**: Consider Redis or Azure Cache for replication if deploying multi-instance
- **For now**: Single-instance ACA deployment with Kubernetes pod affinity to stick sessions to one replica

## Environment Configuration

Set these variables before deploying the Extension backend:

### Required GitHub App Credentials

| Variable | Description | Example |
|----------|-------------|---------|
| `BASECOAT_EXTENSION_GITHUB_APP_ID` | GitHub App ID from registration | `123456` |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_ID` | GitHub OAuth client ID | `Iv1.a1b2c3d4e5f6g7h8` |
| `BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET` | GitHub OAuth client secret (vault-managed) | `(secret)` |
| `BASECOAT_EXTENSION_WEBHOOK_SECRET` | Webhook secret for signature verification | `(secret)` |
| `BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY` | GitHub App private key (PEM format, vault-managed) | `(secret)` |

### Optional Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS` | `600000` | State token TTL (10 minutes) |
| `BASECOAT_EXTENSION_SESSION_TTL_MS` | `86400000` | User session TTL (24 hours) |
| `BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS` | `14400000` | Key rotation interval (4 hours) |
| `BASECOAT_EXTENSION_ALLOWED_ORG` | `IBuySpy-Shared` | GitHub org for membership check |
| `BASECOAT_EXTENSION_OAUTH_CALLBACK_URL` | (auto-inferred) | Explicit callback URL (production use) |
| `BASECOAT_EXTENSION_OAUTH_AUTHORIZE_URL` | (GitHub URL) | Override GitHub OAuth endpoint (testing only) |

### Example `.env`

```bash
# GitHub App credentials (from registration)
BASECOAT_EXTENSION_GITHUB_APP_ID=123456
BASECOAT_EXTENSION_GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET=your_client_secret_here
BASECOAT_EXTENSION_WEBHOOK_SECRET=your_webhook_secret_here
BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"

# Tuning (optional)
BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS=600000
BASECOAT_EXTENSION_SESSION_TTL_MS=86400000
BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS=14400000
BASECOAT_EXTENSION_ALLOWED_ORG=IBuySpy-Shared
BASECOAT_EXTENSION_OAUTH_CALLBACK_URL=https://extension.basecoat.dev/api/github/oauth/callback

# Observability
APPLICATIONINSIGHTS_CONNECTION_STRING=...
```

## Error Handling

### Invalid State

**Scenario**: Callback arrives with `state` parameter that doesn't exist in store or is expired.

**Response** (400 Bad Request):
```json
{
  "error": "invalid_state",
  "error_description": "State token not found or expired. Start a new authorization flow.",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Logging**:
```json
{
  "level": "warn",
  "timestamp": "2024-01-15T10:30:45Z",
  "message": "OAuth state validation failed",
  "incomingState": "xyz789",
  "reason": "not_found",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Expired Session

**Scenario**: User has valid session but TTL elapsed before next request.

**Response** (401 Unauthorized):
```json
{
  "error": "session_expired",
  "error_description": "Your session has expired. Please sign in again.",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Client Action**: Clear cookies/tokens and redirect to `GET /api/github/oauth/authorize`.

### GitHub API Failure (Code Exchange)

**Scenario**: `POST https://github.com/login/oauth/access_token` returns error (e.g., invalid code, revoked app).

**Response** (502 Bad Gateway):
```json
{
  "error": "oauth_backend_failure",
  "error_description": "Failed to exchange auth code with GitHub. Try again.",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Logging**:
```json
{
  "level": "error",
  "timestamp": "2024-01-15T10:30:45Z",
  "message": "GitHub OAuth token exchange failed",
  "githubError": "bad_verification_code",
  "githubErrorUri": "https://docs.github.com/en/developers/apps/building-oauth-apps/troubleshooting-oauth-app-access-token-request-errors",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### User Not in Allowed Org

**Scenario**: User authenticated successfully but is not a member of `BASECOAT_EXTENSION_ALLOWED_ORG`.

**Response** (403 Forbidden):
```json
{
  "error": "unauthorized_organization",
  "error_description": "You must be a member of the IBuySpy-Shared org to use this Extension.",
  "allowed_org": "IBuySpy-Shared",
  "user_login": "bob",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Logging**:
```json
{
  "level": "warn",
  "timestamp": "2024-01-15T10:30:45Z",
  "message": "OAuth succeeded but user not in allowed org",
  "user_login": "bob",
  "allowed_org": "IBuySpy-Shared",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Webhook Signature Validation Failure

**Scenario**: Incoming GitHub webhook doesn't have valid `X-Hub-Signature-256` header.

**Response** (401 Unauthorized):
```json
{
  "error": "invalid_signature",
  "error_description": "Webhook signature verification failed.",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Logging**:
```json
{
  "level": "warn",
  "timestamp": "2024-01-15T10:30:45Z",
  "message": "Webhook signature validation failed",
  "incomingSignature": "sha256=abc123...",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Implementation**:
```javascript
function validateWebhookSignature(payload, incomingSignature) {
  const webhookSecret = process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET;
  const hmac = crypto.createHmac('sha256', webhookSecret);
  hmac.update(payload);
  const expectedSignature = 'sha256=' + hmac.digest('hex');
  
  // Use constant-time comparison to prevent timing attacks
  if (!crypto.timingSafeEqual(
    Buffer.from(incomingSignature),
    Buffer.from(expectedSignature)
  )) {
    throw new Error('Signature mismatch');
  }
}
```

## Rate Limiting on Auth Routes

### Strategy

- **Per-user**: Track by IP address for `/api/github/oauth/authorize` (before auth) and session ID for `/api/github/session/rotate` (after auth)
- **Window**: Sliding 1-minute window
- **Threshold**: 10 requests per window per user
- **Backoff**: Return `429 Too Many Requests` with `Retry-After` header

### Endpoints Covered

| Endpoint | Limit | Window | Tracked By |
|----------|-------|--------|-----------|
| `GET /api/github/oauth/authorize` | 5 req | 1 min | IP address |
| `GET /api/github/oauth/callback` | 10 req | 1 min | IP address |
| `POST /api/github/session/rotate` | 10 req | 1 min | session ID |
| `POST /api/github/session/logout` | 5 req | 1 min | session ID |

### Response (429 Too Many Requests)

```json
{
  "error": "rate_limit_exceeded",
  "error_description": "Too many requests. Please try again later.",
  "retry_after": 23,
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Headers**:
```
HTTP/1.1 429 Too Many Requests
Retry-After: 23
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1634567923
```

### Implementation

```javascript
import RateLimit from 'express-rate-limit';

const oauthAuthorizeLimit = RateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5,
  keyGenerator: (req) => req.ip,
  handler: (req, res) => {
    res.status(429).json({
      error: 'rate_limit_exceeded',
      error_description: 'Too many requests. Please try again later.',
      retry_after: req.rateLimit.resetTime
        ? Math.ceil((req.rateLimit.resetTime - Date.now()) / 1000)
        : 60,
      trace_id: req.id
    });
  },
  skip: (req) => {
    // Optionally skip rate limiting for certain IPs or during maintenance
    return false;
  }
});

app.get('/api/github/oauth/authorize', oauthAuthorizeLimit, (req, res) => {
  // ... handler
});
```

## Session Invalidation & Logout

### Logout Endpoint

**Endpoint**: `POST /api/github/session/logout`

**Request**:
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Backend Actions**:
1. Validate incoming session ID exists
2. Delete from session store
3. Revoke access token at GitHub (optional but recommended)
4. Return success response

**Response** (200 OK):
```json
{
  "status": "logged_out",
  "message": "Session terminated. Please sign in again to continue."
}
```

**Logging**:
```json
{
  "level": "info",
  "timestamp": "2024-01-15T10:35:00Z",
  "message": "User logged out",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_login": "alice"
}
```

## Monitoring & Alerts

### Key Metrics

- **OAuth Success Rate**: % of `GET /api/github/oauth/callback` requests that complete with 200/302
- **State Validation Failures**: Count of `invalid_state` errors per hour
- **Session Expiration Events**: Count of sessions that hit TTL per hour
- **Token Rotation Latency**: p50/p95 of rotation operation duration
- **GitHub API Latency**: p50/p95 of time to exchange code for token

### Log Queries (Kusto)

```kusto
// OAuth success rate
traces
| where message == "OAuth callback succeeded"
| summarize SuccessCount = count() by bin(timestamp, 1h)
| join (
    traces
    | where message startswith "OAuth"
    | summarize TotalCount = count() by bin(timestamp, 1h)
  ) on timestamp
| project timestamp, SuccessRate = SuccessCount * 100.0 / TotalCount
```

```kusto
// State validation failures
traces
| where message == "OAuth state validation failed"
| summarize FailureCount = count() by reason = customDimensions.reason, bin(timestamp, 1h)
```

```kusto
// Session rotation latency
traces
| where message == "Session token rotated"
| extend RotationDurationMs = todouble(customDimensions.duration_ms)
| summarize P50 = percentile(RotationDurationMs, 50), P95 = percentile(RotationDurationMs, 95) by bin(timestamp, 1h)
```

### Alert Conditions

1. **OAuth Success Rate < 95%** → Page on-call
2. **State Validation Failures > 100/hour** → Possible attack, investigate
3. **Session Expiration Rate > 1000/hour** → TTL may be too short, review
4. **GitHub API Latency p95 > 5s** → Investigate GitHub API health

## References

- Issue: [#1112 — OAuth and session flow documentation](https://github.com/IBuySpy-Shared/basecoat/issues/1112)
- GitHub App Registration Runbook: `docs/operations/COPILOT_EXTENSION_GITHUB_APP_REGISTRATION.md`
- Copilot Extension PRD: `docs/design/copilot-extension-prd.md`
- Extension Backend README: `mcp/basecoat-extension/README.md`
- GitHub OAuth Docs: https://docs.github.com/en/developers/apps/building-oauth-apps
- OWASP CSRF Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
