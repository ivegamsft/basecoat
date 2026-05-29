---
description: "Use when working with backend-dev, frontend-dev, middleware-dev, or data-tier agents. Covers shared code style, error handling, security, logging, testing, and agent collaboration expectations."
applyTo: "**/*"
---

# Development Standards

Use this instruction for all development tasks executed by the backend-dev, frontend-dev, middleware-dev, and data-tier agents.

## Code Style

- Use descriptive names for all variables, functions, classes, modules, and files. No single-letter names except loop counters. No abbreviations unless the abbreviation is unambiguous in the domain (e.g., `id`, `url`, `api`).
- Keep functions and methods to 40 lines or fewer. If a function exceeds 40 lines, extract helpers or split responsibilities.
- One concern per function. A function that does more than one thing must be split.
- Avoid magic numbers and magic strings. Extract constants with descriptive names.
- Prefer explicit over implicit — do not rely on framework defaults when the behavior matters for correctness or security.

## Error Handling

- Never swallow exceptions. Every `catch` block must either re-throw, translate to a domain error, or log with context before handling.
- Always log the error context before handling: what operation was in progress, what input triggered it, and the correlation ID.
- Translate low-level errors (database errors, network errors) at the boundary — do not leak implementation details to callers.
- Use typed, named error classes rather than generic `Error`. Each error type maps to a specific HTTP status or response code.
- If an error path is known but cannot be handled now, file a GitHub Issue immediately and add a code comment with the issue number.

## Security Defaults

- No secrets in source code. No secrets in committed configuration files. No secrets in log output.
- Use environment variables or a secrets manager for all credentials, API keys, and tokens.
- Validate all external input at every service boundary — HTTP handlers, message consumers, file processors.
- Parameterize all database queries. String concatenation into queries is never acceptable.
- Apply the principle of least privilege: service accounts and database users have only the permissions they require.
- Every HTTP endpoint requires explicit authentication. No endpoint is implicitly public.
- Set security-relevant HTTP headers on all responses (Content-Security-Policy, X-Frame-Options, etc.).

## Logging

- Use structured (JSON) logging at all times. No plain-text log lines.
- Every log entry must include: `correlationId`, `service`, `level`, `timestamp`, `message`.
- Log levels:
  - `DEBUG` — detailed diagnostic information, disabled in production by default.
  - `INFO` — normal lifecycle events (request started, entity created, job completed).
  - `WARN` — recoverable anomalies or unexpected conditions that do not cause a failure.
  - `ERROR` — failures that require attention. Include the error message and stack.
- Never log: passwords, tokens, API keys, PII (names, emails, phone numbers), or full request bodies that may contain sensitive fields.
- Every request or message processing chain must carry a `correlationId` and log it consistently across all hops.

## Testing

- Every new function needs at least one test before the feature is considered done.
- Every bug fix needs a regression test that reproduces the bug before the fix.
- Test naming must describe the scenario: `given_<precondition>_when_<action>_then_<expected_result>`.
- Tests must cover the positive path (expected behavior) and each named error path (not found, validation failure, unauthorized, etc.).
- Do not test implementation details — test observable behavior through the public interface.
- Mocks and stubs are appropriate for external dependencies (databases, HTTP clients, message brokers). Do not mock the code under test.

## Issue Filing

- Any discovered tech debt must have a GitHub Issue filed before the session ends. Do not defer.
- Use the agent-specific issue templates from the agent files.
- Apply the appropriate label set: `tech-debt` plus the tier label (`backend`, `frontend`, `middleware`, `data`) plus any additional classification (`security`, `performance`, `accessibility`, `reliability`).
- A comment referencing the issue number must be left in the code at the discovery site: `// See #<N> — <short description>`.

## Agent Collaboration and Handoffs

The four dev core agents operate as a coordinated team. Follow this handoff order:

1. **backend-dev** defines API contracts (OpenAPI spec) and service interfaces. These become the authoritative source of truth for what data is available and how it is shaped.
2. **frontend-dev** consumes the API contracts defined by backend-dev. Frontend components must not assume data shapes that are not in the contract. Any needed contract change goes back to backend-dev.
3. **middleware-dev** connects backend services to external systems, message brokers, or other internal services. Middleware consumes the same contracts as frontend where applicable and defines its own message schemas at integration boundaries.
4. **data-tier** persists the entities that backend-dev's service layer operates on. The data-tier agent aligns schema and repository patterns with the service contracts backend-dev defines.

**Conflict resolution:** When two agents need to agree on a shape, the backend-dev agent's API contract is the tie-breaker. Data-tier changes that break the contract require backend-dev review before merging.

**No agent should:**
- Bypass the repository pattern to call the database from a handler or middleware layer.
- Embed API-response formatting logic in a repository or data access function.
- Define business rules in a migration, query, or infrastructure configuration.
