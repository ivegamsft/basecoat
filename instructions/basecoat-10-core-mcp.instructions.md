---
description: "Use when configuring, invoking, building, or reviewing MCP servers and MCP tool usage. Covers server development standards, tool definition conventions, transport protocols, trust boundaries, secrets handling, testing, and safe operation patterns."
applyTo: "**/*.{md,json,yml,yaml,ts,js,py,ps1,sh}"
---

# MCP Standards

Use this instruction for any change that adds, modifies, or relies on MCP servers, MCP tools, or model-tool workflows.

## Server Development Standards

- Use the official MCP SDK for the target language. Do not implement the protocol from scratch.
- Declare server name, version, and capabilities during initialization.
- Register all tools, resources, and prompts at startup — not lazily or on-demand.
- Implement the full server lifecycle: `initialize` → handle requests → `shutdown` gracefully.
- Handle all errors inside tool handlers. Never let an unhandled exception crash the server.
- Return MCP-compliant error responses with meaningful codes and human-readable messages.
- Pin SDK and dependency versions. Do not use floating latest references in production.

## Tool Definition Conventions

- Use kebab-case for tool names: `query-database`, `create-issue`, `run-analysis`.
- Every tool must have a clear `description` explaining what it does, when to use it, and any side effects.
- Define `inputSchema` as a complete JSON Schema with `required` fields, types, descriptions, and constraints.
- Set `additionalProperties: false` on input schemas to reject unexpected parameters.
- Return structured results in a consistent envelope shape across all tools in a server.
- Mark destructive tools (create, update, delete, deploy) clearly in their description.
- Prefer many focused tools over one tool with a `mode` or `action` parameter.

## Transport Protocol Selection

| Transport | Use when | Avoid when |
|---|---|---|
| **stdio** | Local CLI tools, editor plugins, same-machine IPC | Multi-client or networked deployments |
| **SSE** | Server-push to browser clients, legacy integrations | New production servers (use Streamable HTTP) |
| **Streamable HTTP** | Production web deployments, multi-client servers | Simple local integrations (use stdio) |

- Default to Streamable HTTP for new server projects unless the deployment requires stdio.
- Use TLS for any transport exposed beyond localhost.
- Set explicit timeouts: connection (10s), request (30s), idle (300s).
- Configure reconnection with exponential backoff (1–60 seconds) for SSE and HTTP clients.
- Do not write non-protocol output to stdout when using stdio transport. Use stderr for logging.

## Trust and Governance

- Treat every MCP server as an external trust boundary unless it is owned, reviewed, and pinned by your organization.
- Use an explicit allowlist of approved MCP servers and approved tools per server.
- Pin server versions and client dependencies. Do not use floating latest references for production usage.
- Define approved MCP servers in a central registry document owned by the COE.
- Every approved server entry must include owner, purpose, data classification, auth method, and last review date.
- Add a deprecation process so old servers can be retired without breaking consumers.
- Require architecture or security review for any new MCP server integration.
- Track changes to MCP policy through versioned standards and amendments.

## Security Considerations

- Scope credentials to least privilege and store secrets in secure configuration, not source control.
- Prefer short-lived credentials and managed identity where supported by the host platform.
- Require explicit user confirmation before any MCP tool can create, delete, deploy, or mutate external systems.
- For GitHub mutating actions (`issue`, `pr`, `comment`, labels, project updates), enforce repository-target preflight checks against an internal allowlist and block unknown/external repos by default.
- Validate all MCP tool inputs and sanitize model-generated arguments before execution.
- Enforce authentication on every transport endpoint in production — even on internal networks.
- Use OAuth 2.1 or API key authentication at the transport layer. Prefer short-lived tokens.
- Enforce per-tool authorization. Not every authenticated client should access every tool.
- Do not send sensitive payloads to MCP servers unless data classification and retention are approved.
- Never log secrets, tokens, PII, or full request bodies that may contain sensitive fields.
- Set CORS policies when serving browser-based clients. Never use wildcard origins in production.

## Testing Requirements

- **Unit tests**: test each tool handler in isolation with mocked external dependencies.
- **Integration tests**: start the server, connect a test client, run `initialize`, invoke each tool, verify responses.
- **Schema validation tests**: confirm every tool's `inputSchema` is valid JSON Schema and handlers reject non-conforming input.
- **Transport tests**: verify behavior under connection drop, reconnection, concurrent requests, and malformed input.
- **Security tests**: verify unauthorized requests are rejected, scopes are enforced, and no secrets leak in errors.
- Achieve minimum 80% code coverage on tool handler logic.

## Integration Patterns

- Use environment variables for all runtime configuration: port, log level, auth settings, upstream URLs.
- Log tool invocation metadata for auditability, including tool name, caller context, and outcome.
- Set timeout, retry, and circuit-breaker behavior for MCP operations to avoid runaway execution.
- Expose a `/health` endpoint on HTTP-based servers for liveness and readiness probes.
- Package stdio servers as standalone executables or containers with a clear entrypoint.
- Deploy HTTP-based servers behind a reverse proxy with TLS termination and rate limiting.
- Document the server's tool manifest, required environment variables, and deployment steps in a README.

## Review Lens

- Is this MCP server approved and documented by the COE?
- Does the server declare capabilities and register all tools at startup?
- Are tool permissions limited to the minimum needed for this scenario?
- Are tool input schemas complete with required fields, types, and constraints?
- Could model output trigger unsafe tool actions without a human checkpoint?
- Are secrets, PII, and regulated data protected before any MCP call is made?
- Are audit logs sufficient to reconstruct who invoked which tool and why?
- Is the integration resilient to server outages and partial failures?
- Are transport timeouts and reconnection policies configured?
