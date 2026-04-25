# Repository Pattern Template

Use this template to scaffold a data access repository. The pattern is ORM-agnostic — adapt the query syntax to the database driver or ORM in use. Keep all query logic here; no SQL or query builder calls belong in the service layer.

---

## Repository Contract

Define the interface before writing the implementation.

```
Repository: <Entity>Repository
Entity: <Entity>
Primary key type: string (UUID) | integer
Soft delete: yes | no
```

---

## Interface Definition

```
interface <Entity>Repository {
  findById(id: string): Promise<<Entity> | null>
  findMany(filters: <Entity>Filters): Promise<PaginatedResult<<Entity>>>
  create(input: Create<Entity>Input): Promise<<Entity>>
  update(id: string, input: Partial<Create<Entity>Input>): Promise<<Entity>>
  delete(id: string): Promise<void>
  exists(id: string): Promise<boolean>
}
```

---

## Implementation Scaffold

```
class <Entity>DatabaseRepository implements <Entity>Repository {

  constructor(private readonly db: DatabaseClient) {}

  async findById(id: string): Promise<<Entity> | null> {
    // Parameterized query — never concatenate id into the query string
    const row = await this.db.queryOne(
      "SELECT id, field_one, field_two, created_at, updated_at FROM <table> WHERE id = $1 AND deleted_at IS NULL",
      [id]
    )
    if (!row) return null
    return this.mapRowToEntity(row)
  }

  async findMany(filters: <Entity>Filters): Promise<PaginatedResult<<Entity>>> {
    // Always apply pagination — never fetch unbounded result sets
    const { pageSize = 20, cursor } = filters

    const params: unknown[] = [pageSize + 1]  // fetch one extra to detect next page
    const conditions: string[] = ["deleted_at IS NULL"]

    if (cursor) {
      conditions.push(`id > $${params.length + 1}`)
      params.push(cursor)
    }

    // Add additional filter conditions here following the same pattern

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : ""

    const rows = await this.db.query(
      `SELECT id, field_one, field_two, created_at, updated_at FROM <table> ${whereClause} ORDER BY id ASC LIMIT $1`,
      params
    )

    const hasNextPage = rows.length > pageSize
    const data = rows.slice(0, pageSize).map(this.mapRowToEntity)

    return {
      data,
      pagination: {
        pageSize,
        nextCursor: hasNextPage ? data[data.length - 1].id : null
      }
    }
  }

  async create(input: Create<Entity>Input): Promise<<Entity>> {
    const row = await this.db.queryOne(
      `INSERT INTO <table> (field_one, field_two, created_at, updated_at)
       VALUES ($1, $2, NOW(), NOW())
       RETURNING id, field_one, field_two, created_at, updated_at`,
      [input.fieldOne, input.fieldTwo]
    )
    return this.mapRowToEntity(row)
  }

  async update(id: string, input: Partial<Create<Entity>Input>): Promise<<Entity>> {
    // Build SET clause dynamically but safely — only set columns that were provided
    const setClauses: string[] = ["updated_at = NOW()"]
    const params: unknown[] = [id]

    if (input.fieldOne !== undefined) {
      setClauses.push(`field_one = $${params.length + 1}`)
      params.push(input.fieldOne)
    }
    if (input.fieldTwo !== undefined) {
      setClauses.push(`field_two = $${params.length + 1}`)
      params.push(input.fieldTwo)
    }

    const row = await this.db.queryOne(
      `UPDATE <table> SET ${setClauses.join(", ")} WHERE id = $1 AND deleted_at IS NULL
       RETURNING id, field_one, field_two, created_at, updated_at`,
      params
    )

    if (!row) throw new NotFoundError("<Entity>", id)
    return this.mapRowToEntity(row)
  }

  async delete(id: string): Promise<void> {
    // Hard delete — use soft delete variant below if the domain requires it
    await this.db.execute(
      "DELETE FROM <table> WHERE id = $1",
      [id]
    )
  }

  // Soft delete variant — use instead of hard delete when audit/recovery is required
  async softDelete(id: string): Promise<void> {
    await this.db.execute(
      "UPDATE <table> SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL",
      [id]
    )
  }

  async exists(id: string): Promise<boolean> {
    const row = await this.db.queryOne(
      "SELECT 1 FROM <table> WHERE id = $1 AND deleted_at IS NULL",
      [id]
    )
    return row !== null
  }

  // -------------------------------------------------------------------------
  // Private: row → domain entity mapping
  // -------------------------------------------------------------------------
  private mapRowToEntity(row: Record<string, unknown>): <Entity> {
    return {
      id: row.id as string,
      fieldOne: row.field_one as string,
      fieldTwo: row.field_two as string,
      createdAt: row.created_at as Date,
      updatedAt: row.updated_at as Date
    }
  }
}
```

---

## Checklist

Before shipping a repository implementation:

- [ ] All queries use parameterized placeholders — no string concatenation of user input.
- [ ] All collection queries have a `LIMIT` clause and return `nextCursor` or equivalent.
- [ ] The `mapRowToEntity` function maps every column — no implicit `*` leakage.
- [ ] Soft deletes filter on `deleted_at IS NULL` in every read query.
- [ ] The repository interface is tested with both a real database (integration) and a mock (unit).
- [ ] No business logic exists in this file — only query construction and row mapping.
