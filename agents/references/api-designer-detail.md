# API Designer — Detail Reference

Full detail supporting `agents/basecoat-10-core-api-designer.agent.md`.

## REST API Design Principles

- Use resource-oriented URLs: `GET /orders/{id}`, not `GET /getOrder?id=`.
- HTTP methods must match semantics: `GET` reads, `POST` creates, `PUT` replaces, `PATCH` partially updates, `DELETE` removes.
- HTTP status codes must be accurate: `200` for success, `201` for created, `204` for no content, `400` for client error, `401` for unauthenticated, `403` for unauthorized, `404` for not found, `409` for conflict, `422` for validation failure, `429` for rate limit, `500` for server fault.
- Support pagination on all collection endpoints using cursor-based or offset+limit pagination. Include `total`, `pageSize`, and `nextCursor` in responses.
- Return consistent error envelopes on all non-2xx responses (see `skills/api-design/openapi-template.md`).
- Use `camelCase` for JSON field names. Use plural nouns for resource names.
- Support filtering, sorting, and field selection on collection endpoints where appropriate.

## GraphQL Schema Design Principles

- Use a single graph — avoid multiple schemas that expose the same domain.
- Name types after domain concepts (`Order`, `Customer`), not implementation details (`OrderRow`, `CustomerDTO`).
- Use `input` types for mutations. Never accept raw JSON scalars.
- Return domain types from mutations, not generic success/failure booleans.
- Implement cursor-based pagination using the Relay connection pattern (`edges`, `node`, `pageInfo`).
- Every field should have a description. Undocumented fields are contract violations.
- Use `@deprecated(reason: "...")` for fields being phased out. Never remove a field without a deprecation cycle.

## Versioning Strategy

- **Default:** URL-prefix versioning (`/v1/`, `/v2/`).
- **Alternative:** `Accept` header negotiation (`Accept: application/vnd.api.v2+json`) when URL versioning is impractical.
- **Rules:**
  - Non-breaking changes (add optional fields, add new endpoints) go into the current version.
  - Breaking changes (remove fields, change types, rename paths) require a new major version.
  - Deprecated versions must remain functional for at least two release cycles or a documented sunset period.
  - Publish a changelog entry for every version increment.
- See `skills/api-design/versioning-decision-tree.md` for the full decision flow.

## Breaking-Change Detection

Before merging any spec change, evaluate against the breaking-change checklist:

| Change | Breaking? |
|---|---|
| Add optional field to request or response | No |
| Add a new endpoint | No |
| Add a new optional query parameter | No |
| Remove a field from response | **Yes** |
| Remove an endpoint | **Yes** |
| Rename a field | **Yes** |
| Change a field type or format | **Yes** |
| Change an HTTP method or path | **Yes** |
| Make an optional field required | **Yes** |
| Narrow an enum (remove values) | **Yes** |
| Widen an enum (add values) | No (response and request, per `skills/api-design/breaking-change-checklist.md`) |
| Change authentication scheme | **Yes** |
| Change error response structure | **Yes** |

See `skills/api-design/breaking-change-checklist.md` for the full checklist with mitigation guidance.

## API Governance

All API specs must pass the governance checklist before approval:

- Every endpoint has explicit authentication and authorization defined.
- Every request and response schema is fully documented with types, descriptions, and examples.
- Every error code is cataloged with an HTTP status, message, and resolution hint.
- Pagination is implemented on all collection endpoints.
- Rate limiting strategy is documented.
- Deprecation policy is documented for any sunset fields or endpoints.
- Naming conventions are consistent across the entire spec.
- No undocumented behavior — if it is not in the spec, it does not exist.

See `skills/api-design/api-governance-checklist.md` for the full governance checklist.

## Issue Filing — Finding-to-Label Map

| Finding | Labels |
|---|---|
| Undocumented endpoint or field | `api-design,contract-violation` |
| Breaking change without version bump | `api-design,contract-violation,breaking-change` |
| Missing authentication on a public endpoint | `api-design,contract-violation,security` |
| Inconsistent naming (mix of camelCase/snake_case) | `api-design,contract-violation` |
| Collection endpoint without pagination | `api-design,contract-violation` |
| Missing error envelope or undocumented error code | `api-design,contract-violation` |
| Deprecated field without sunset timeline | `api-design,contract-violation` |
