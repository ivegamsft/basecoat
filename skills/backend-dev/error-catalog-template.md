# Error Catalog Template

Use this catalog to document every structured error code the service can return. Every error code that appears in an API response must have an entry here. Keep this catalog in source control alongside the service code.

---

## Catalog Format

| Field | Description |
|---|---|
| **Code** | Machine-readable, UPPER_SNAKE_CASE string. Stable — do not rename once published. |
| **HTTP Status** | The HTTP status code returned with this error. |
| **Message** | Human-readable message. Safe to display. No internal details. |
| **Resolution Hint** | What the caller should do to resolve the error. |
| **Retryable** | Whether the caller may retry the request unchanged. |

---

## Global Errors (all endpoints)

| Code | HTTP Status | Message | Resolution Hint | Retryable |
|---|---|---|---|---|
| `UNAUTHENTICATED` | 401 | Authentication is required. | Provide a valid Bearer token in the Authorization header. | No |
| `UNAUTHORIZED` | 403 | You do not have permission to perform this action. | Verify your account has the required role or scope. | No |
| `NOT_FOUND` | 404 | The requested resource does not exist. | Check the resource ID and try again. | No |
| `CONFLICT` | 409 | The request conflicts with the current state of the resource. | Refresh the resource and retry with updated data. | No |
| `VALIDATION_FAILED` | 422 | The request body is invalid. See `details` for field-level errors. | Correct the indicated fields and resubmit. | No |
| `RATE_LIMITED` | 429 | Too many requests. | Wait before retrying. Respect the `Retry-After` response header. | Yes |
| `INTERNAL_ERROR` | 500 | An unexpected error occurred. | Retry after a brief delay. If the problem persists, contact support with the `correlationId`. | Yes |
| `SERVICE_UNAVAILABLE` | 503 | The service is temporarily unavailable. | Retry with exponential backoff. | Yes |

---

## Resource-Specific Errors

Add one section per resource. Copy the table pattern from the global section.

### `<Resource>` Errors

| Code | HTTP Status | Message | Resolution Hint | Retryable |
|---|---|---|---|---|
| `<RESOURCE>_ALREADY_EXISTS` | 409 | A `<resource>` with this identifier already exists. | Use a different identifier or update the existing resource. | No |
| `<RESOURCE>_LIMIT_EXCEEDED` | 422 | You have reached the maximum allowed number of `<resource>s`. | Remove an existing `<resource>` before creating a new one. | No |
| `<RESOURCE>_INVALID_STATE` | 422 | This operation is not allowed in the current state of the `<resource>`. | Check the resource status and apply the operation only when it is in a valid state. | No |

---

## Error Envelope Reference

Every non-2xx response body must conform to this shape:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The request body is invalid.",
    "details": [
      {
        "field": "email",
        "issue": "must be a valid email address"
      },
      {
        "field": "name",
        "issue": "is required"
      }
    ],
    "correlationId": "a1b2c3d4-0000-0000-0000-000000000000"
  }
}
```

- `code` — always present. Machine-readable. From this catalog.
- `message` — always present. Human-readable. Safe to display to end users.
- `details` — present on `VALIDATION_FAILED`. Field-level errors. Omitted on other error types.
- `correlationId` — always present. Use this when reporting issues to support.

---

## Governance Rules

- New error codes must be added to this catalog before the endpoint ships.
- Existing codes must not be renamed — consumers depend on them.
- Internal exception messages, stack traces, and database errors must never appear in `message` or `details`.
- If a new HTTP status code is used, document it in the Global Errors table.
