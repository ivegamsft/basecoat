# Backend Development Agent — Detail Reference

Full standards for `agents/basecoat-10-core-backend-dev.agent.md`.

## API Design Principles

- Use resource-oriented URLs: `GET /orders/{id}`, not `GET /getOrder?id=`.
- HTTP status codes must be accurate: `200` for success, `201` for created, `400` for client error, `401` for unauthenticated, `403` for unauthorized, `404` for not found, `409` for conflict, `422` for validation failure, `500` for server fault.
- Support pagination on all collection endpoints using cursor or offset+limit. Include `total`, `page`, `pageSize`, and `nextCursor` in responses.
- Version APIs via URL prefix (`/v1/`) or `Accept` header negotiation. Never break an existing version.
- Return consistent error envelopes on all non-2xx responses (see Error Handling).

## Service Layer Patterns

- One service per bounded context. Do not let services directly call other services' repositories.
- Inject all external dependencies (repositories, message clients, config) via constructor or parameter — never instantiate them inside service methods.
- Keep business rules in the service layer, not in HTTP handlers or repositories.
- Use domain-specific exceptions or result types rather than returning raw HTTP errors from services.
- Functions longer than 40 lines are a signal to extract a helper or split responsibilities.

## Error Handling

Return a consistent structured error envelope on all error responses:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The request body is invalid.",
    "details": [
      { "field": "email", "issue": "must be a valid email address" }
    ],
    "correlationId": "a1b2c3d4-..."
  }
}
```

- Never swallow exceptions. Always log with context before re-throwing or translating.
- Map domain exceptions to HTTP status codes at the transport boundary, not inside services.
- Maintain an error catalog (see `skills/backend-dev/error-catalog-template.md`) so all error codes are documented.

## Input Validation

- Validate all input at the service boundary before any business logic executes.
- Enforce types, required fields, length limits, format constraints, and business-rule constraints.
- Return `422 Unprocessable Entity` with field-level detail for validation failures.
- Never trust input from clients, even authenticated ones.

## Logging Standards

- Use structured (JSON) logging at all times.
- Every log entry must include: `correlationId`, `service`, `level`, `timestamp`, `message`.
- Log at `INFO` for normal request lifecycle, `WARN` for recoverable anomalies, `ERROR` for failures requiring attention.
- Never log secrets, passwords, tokens, PII, or full request bodies that may contain sensitive fields.
- Include the HTTP method, route, and status code in request completion logs.

## Security Defaults

- Every endpoint must have explicit auth — no endpoint is implicitly public.
- Use parameterized queries or ORM-level binding for all database access. Never concatenate user input into queries.
- Store no secrets in source code or committed config files. Use environment variables or a secrets manager.
- Validate and sanitize inputs before passing them to any downstream system.
- Apply the principle of least privilege to service accounts and database credentials.
- Set appropriate CORS policies — do not default to wildcard in production.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Tech Debt]`
- **Base labels:** `tech-debt,backend`
- **Category options:** `<N+1 risk | missing validation | unhandled error path | hardcoded value | missing auth>`
- **File:** `<path/to/file.ext>`

| Finding | Labels |
|---|---|
| Query loop inside a loop — N+1 risk | `tech-debt,backend,performance` |
| Missing input validation on a public endpoint | `tech-debt,backend,security` |
| Unhandled exception path or swallowed error | `tech-debt,backend` |
| Hardcoded value that should be config | `tech-debt,backend` |
| Endpoint missing authentication or authorization check | `tech-debt,backend,security` |
