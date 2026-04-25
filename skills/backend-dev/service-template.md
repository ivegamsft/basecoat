# Service Layer Template

Use this template to scaffold a service class or module. Replace all `<placeholder>` values. The pattern is framework-agnostic — adapt the syntax to the language and runtime in use.

---

## Service Contract

Define the public interface for this service before writing the implementation.

```
Service: <ServiceName>
Bounded context: <what domain concern this service owns>
Dependencies: <list external dependencies — repositories, message clients, config>
```

---

## Pseudocode Scaffold

The following scaffold shows the expected structure. Implement in the project language.

```
class <ServiceName>Service {

  // Injected dependencies — never construct inside service methods
  repository: <EntityRepository>
  logger: Logger
  // Add other dependencies: messageClient, cacheClient, configService, etc.

  constructor(repository, logger, /* other deps */) {
    this.repository = repository
    this.logger = logger
    // Assign remaining deps
  }

  // -------------------------------------------------------------------------
  // Public methods — one method per use case
  // -------------------------------------------------------------------------

  async create<Entity>(input: Create<Entity>Input): Promise<<Entity>> {
    // 1. Validate input
    validate(input)  // throws ValidationError with field details on failure

    // 2. Apply business rules
    // ... domain logic here

    // 3. Persist via repository
    const entity = await this.repository.create(input)

    // 4. Log the operation
    this.logger.info({
      event: "<entity>.created",
      entityId: entity.id,
      correlationId: context.correlationId
    })

    // 5. Return the created entity
    return entity
  }

  async get<Entity>ById(id: string): Promise<<Entity> | null> {
    const entity = await this.repository.findById(id)

    if (!entity) {
      this.logger.warn({
        event: "<entity>.not_found",
        id,
        correlationId: context.correlationId
      })
      return null  // caller translates null to 404
    }

    return entity
  }

  async update<Entity>(id: string, input: Update<Entity>Input): Promise<<Entity>> {
    // 1. Validate input
    validate(input)

    // 2. Verify entity exists
    const existing = await this.repository.findById(id)
    if (!existing) {
      throw new NotFoundError("<Entity>", id)
    }

    // 3. Apply business rules
    // ... merge changes, enforce invariants

    // 4. Persist
    const updated = await this.repository.update(id, input)

    this.logger.info({
      event: "<entity>.updated",
      entityId: id,
      correlationId: context.correlationId
    })

    return updated
  }

  async delete<Entity>(id: string): Promise<void> {
    const existing = await this.repository.findById(id)
    if (!existing) {
      throw new NotFoundError("<Entity>", id)
    }

    await this.repository.delete(id)

    this.logger.info({
      event: "<entity>.deleted",
      entityId: id,
      correlationId: context.correlationId
    })
  }

  async list<Entity>s(filters: <Entity>Filters): Promise<PaginatedResult<<Entity>>> {
    // Enforce pagination — never return unbounded results
    const pageSize = Math.min(filters.pageSize ?? 20, 100)

    return this.repository.list({ ...filters, pageSize })
  }

  // -------------------------------------------------------------------------
  // Private helpers — kept private, each under 40 lines
  // -------------------------------------------------------------------------

  private validate(input: unknown): asserts input is Valid<Entity>Input {
    // Enforce types, required fields, length limits, format constraints
    // Throw ValidationError with field-level details on failure
  }
}
```

---

## Error Types to Define

| Error type | When to throw | HTTP mapping |
|---|---|---|
| `ValidationError` | Input fails schema or business rule | `422` |
| `NotFoundError` | Entity does not exist | `404` |
| `ConflictError` | Unique constraint or optimistic lock failure | `409` |
| `UnauthorizedError` | Auth check fails inside domain logic | `403` |
| `ServiceError` | Unexpected internal failure | `500` |

---

## Logging Checklist

Every service method must log:

- [ ] Operation started (optional, for long-running operations)
- [ ] Operation succeeded (INFO, include entity ID and correlationId)
- [ ] Validation failure (WARN, include field details — no PII)
- [ ] Not found (WARN, include the looked-up ID)
- [ ] Unexpected error (ERROR, include error message and stack — no secrets)

---

## Testing Expectations

- Unit tests mock all repositories and external clients.
- One test per positive path (happy path for each public method).
- One test per named error path (not found, validation failure, conflict, etc.).
- Verify that the repository was called with the expected arguments.
- Verify that the logger was called with the expected event names.
