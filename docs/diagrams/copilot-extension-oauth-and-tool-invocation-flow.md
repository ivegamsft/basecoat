# Copilot Extension OAuth and Tool Invocation Request Flow

Request-flow reference for the BaseCoat Copilot Extension runtime.

- Source of truth: `mcp/basecoat-extension/src/app.ts`
- Integration entrypoint: `mcp/basecoat-extension/README.md`

---

## 1. OAuth callback pipeline (`GET /api/github/oauth/callback`)

```mermaid
flowchart TD
    A["GET /api/github/oauth/callback?code&state"] --> B["requireOAuthCallbackParams"]
    B -->|Missing code or state| B_ERR["400 invalid_request<br/>oauth_callback_rejected(reason=missing_params)"]
    B --> C["requireOAuthTokenExchangeStubEnabled"]
    C -->|Stub flag disabled| C_BLOCK["503 blocked_external_dependency<br/>blockedByIssue=#1073"]
    C --> D["requireOAuthStateSession"]
    D -->|State invalid or expired| D_ERR["403 invalid_state<br/>oauth_callback_rejected(reason=invalid_state)"]
    D --> E["Route handler logs oauth_callback_stubbed"]
    E --> F["200 token_exchange_stubbed<br/>blockedByIssue=#1073"]
```

---

## 2. Tool execution path (`POST /api/copilot/tools/:toolName`)

```mermaid
flowchart TD
    A["POST /api/copilot/tools/:toolName"] --> RL["createRateLimiter() via app.use('/api/copilot', ...)"]
    RL --> B["parseToolName(req.params.toolName)"]
    B -->|Unknown toolName| B_404["404 error=unknown_tool<br/>logger.warn(tool_invocation)"]
    B --> C["writeTools.execute(toolName, req.body)"]
    C -->|result.status=error and errorCode=unknown_tool| C_404["404 result payload"]
    C -->|result.status=error (other)| C_400["400 result payload"]
    C -->|result.status=blocked| C_503["503 result payload"]
    C -->|result.status=ok or needs_confirmation| C_200["200 result payload<br/>logger.info(tool_invocation)"]
```

---

## 3. Health and ping path (`GET /health`, `GET /api/copilot/ping`)

```mermaid
flowchart TD
    subgraph Liveness
        H1["GET /health"] --> H2["Return status, service, timestamp, rateLimit"]
        H2 --> H3["200 status=ok"]
    end

    subgraph CopilotRuntimeProbe
        P1["GET /api/copilot/ping"] --> P2["extensionTracer.startSpan('copilot.ping')"]
        P2 --> P3["runtime.ping()"]
        P3 -->|Success| P4["logger.info(tool_invocation,status=ok)"]
        P4 --> P5["200 status=ok with copilot payload"]
        P3 -->|Throws error| P6["span.recordException + span.setStatus(ERROR)<br/>logger.error(tool_invocation,status=error)"]
        P6 --> P7["503 status=degraded"]
    end
```

---

## Assumptions

1. OAuth callback token exchange remains intentionally stubbed behind `BASECOAT_EXTENSION_ENABLE_OAUTH_TOKEN_EXCHANGE_STUB=true` until issue #1073 is unblocked (as documented in runtime responses).
2. Tool response branches are based on `WriteToolService.execute(...)` status values in current runtime behavior (`error`, `blocked`, `ok`, `needs_confirmation`).
3. `/health` is liveness-only; tracing and Copilot dependency checks are intentionally done on `/api/copilot/ping`.
