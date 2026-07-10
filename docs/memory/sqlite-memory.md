# SQLite Persistent Memory Specification

Defines a persistent memory MCP server for Base Coat agents using SQLite so useful context survives across sessions, session rotation, and agent restarts.

> **Tracking:** Issue [#144](https://github.com/IBuySpy-Shared/basecoat/issues/144)

> **Ownership:** The SQLite memory store is org-private. It accumulates from your team's usage and reflects your codebase, conventions, and history. The `.db` file is git-ignored and never travels upstream. Each org that adopts BaseCoat builds their own memory store from scratch.

---

## 1. Overview

A SQLite-backed memory service gives agents a small, durable knowledge base that is local, queryable, and easy to operate.

It is intended to store:

- Facts discovered during work
- User preferences explicitly stated during prior sessions
- Decisions made while implementing or reviewing changes
- Project context such as conventions, workflows, and known constraints

Key goals:

- Preserve memory across session rotation and agent restarts
- Support precise retrieval through SQL filters
- Keep storage simple enough for local-first and enterprise deployments
- Make memory usable from hooks without requiring agent-specific logic

SQLite is a good fit because it is embedded, portable, transactional, and supports both structured lookup and optional vector extensions.

---

## 2. Design Goals

The persistent memory server should be:

- **Durable**: memories survive process restarts and session turnover
- **Queryable**: agents can retrieve exact matches by subject, category, or keywords
- **Composable**: hooks and agents can both call the same MCP tools
- **Lightweight**: no external service dependency is required for the baseline implementation
- **Safe**: sensitive content is excluded or sanitized before persistence
- **Extensible**: embeddings and relation graphs can be added without redesigning the core schema

---

## 3. Core Schema Design

The baseline schema stores individual memory records plus lightweight links between related memories.

```sql
CREATE TABLE memories (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL,           -- 'fact', 'preference', 'decision', 'convention'
    subject TEXT NOT NULL,            -- topic tag (e.g., 'testing', 'auth', 'deployment')
    content TEXT NOT NULL,            -- the memory itself
    source TEXT,                      -- where it came from (file path, user input, inference)
    confidence REAL DEFAULT 1.0,      -- 0.0-1.0, decays over time
    created_at TEXT NOT NULL,
    last_accessed TEXT,
    access_count INTEGER DEFAULT 0,
    expires_at TEXT,                  -- optional TTL
    tier TEXT DEFAULT 'l4',           -- 'l0'|'l1'|'l2'|'l3'|'l4' — lookup hierarchy tier
    heat TEXT DEFAULT 'cold',         -- 'cold'|'warm'|'hot' — derived from access_count
    pinned INTEGER DEFAULT 0,         -- 1 = exempt from decay/demotion (security, governance)
    promotion_count INTEGER DEFAULT 0,-- number of tier promotions
    last_promoted_at TEXT             -- ISO 8601 timestamp of last tier promotion
);

CREATE TABLE memory_relations (
    from_id TEXT NOT NULL,
    to_id TEXT NOT NULL,
    relation_type TEXT,               -- 'supports', 'contradicts', 'refines'
    PRIMARY KEY (from_id, to_id)
);

CREATE INDEX idx_memories_subject ON memories(subject);
CREATE INDEX idx_memories_category ON memories(category);
CREATE INDEX idx_memories_tier ON memories(tier);
CREATE INDEX idx_memories_heat ON memories(heat);
```

### `memories`

Each row represents one reusable unit of context.

| Column | Purpose |
|--------|---------|
| `id` | Stable identifier, typically a UUID or deterministic hash |
| `category` | Memory type such as `fact`, `preference`, `decision`, or `convention` |
| `subject` | Topic tag used for filtering and preload rules |
| `content` | The actual memory to inject or retrieve |
| `source` | Provenance for auditing and trust decisions |
| `confidence` | Relevance or trust score that can decay over time |
| `created_at` | Creation timestamp in ISO 8601 format |
| `last_accessed` | Most recent retrieval timestamp |
| `access_count` | Recall frequency for ranking and pruning |
| `expires_at` | Optional TTL for temporary context |
| `tier` | Lookup hierarchy tier: `l0`–`l4`. Determines retrieval cost and loading strategy |
| `heat` | Access frequency bucket: `cold` (0–2), `warm` (3–9), `hot` (10+) — updated on each access |
| `pinned` | When `1`, exempt from decay and demotion; use for security and governance rules |
| `promotion_count` | Number of tier promotions; high values indicate stable, high-value patterns |
| `last_promoted_at` | Timestamp of last promotion; used to assess promotion velocity |

### Heat Thresholds

| `access_count` | `heat` |
|---|---|
| 0–2 | `cold` |
| 3–9 | `warm` |
| 10+ | `hot` |

### `memory_relations`

Relations allow a memory graph to emerge without requiring a full knowledge graph system.

Examples:

- A convention memory can `support` a broader project fact
- A new decision can `refine` an older one
- A corrected memory can `contradict` stale guidance

This table enables conflict handling, lineage, and future graph-aware recall strategies.

---

## 4. MCP Tool Interface

The MCP server exposes a small set of tools that map cleanly to CRUD and recall workflows.

### `memory_store(category, subject, content, source)`

Stores a new memory.

Expected behavior:

- Generate or accept a stable memory ID
- Validate `category` against the allowed set
- Normalize timestamps on write
- Reject content that appears to contain secrets or disallowed data
- Optionally merge with an existing near-duplicate memory

Example:

```text
memory_store(
  category="convention",
  subject="testing",
  content="Run pwsh tests/run-tests.ps1 before merge.",
  source="docs/CONTRIBUTING.md"
)
```

### `memory_recall(subject?, category?, query?)`

Retrieves memories using exact filters, keyword search, or optional semantic similarity.

Expected behavior:

- Support subject-only recall for preload scenarios
- Support category filtering for targeted retrieval
- Support query text for keyword or semantic search
- Rank results by confidence, recency, and access history
- Update `last_accessed` and increment `access_count` on successful recall

Example:

```text
memory_recall(subject="testing", category="convention", query="run tests before merge")
```

### `memory_forget(id)`

Deletes a memory by ID.

Expected behavior:

- Remove the memory record
- Remove or cascade any relations tied to the deleted memory
- Record deletion in telemetry or audit logs if enabled

### `memory_update(id, content)`

Updates an existing memory and bumps confidence.

Expected behavior:

- Replace or revise the stored content
- Increase confidence when the update confirms the memory remains valid
- Refresh `last_accessed` or store a separate `updated_at` field in extended implementations
- Preserve provenance where possible

### `memory_list(limit?, category?)`

Returns a browsable list of stored memories.

Expected behavior:

- Default to a small limit for interactive browsing
- Support category-based inspection
- Sort by recency, confidence, or access frequency
- Exclude expired memories by default

---

## 5. Memory Lifecycle

Persistent memory is only useful if creation, retrieval, decay, and cleanup are intentional.

### Creation

Agents store memories during normal work when they discover durable information such as:

- Repo conventions
- User preferences stated explicitly
- Repeated error signatures and successful fixes
- Decisions that should survive a future session handoff

Creation should favor concise, atomic memories over long summaries.

### Retrieval

Memory should be loaded automatically when relevant.

Typical retrieval points:

- Session bootstrap for repo or project context
- Before tool calls when a subject-specific hint may prevent failure
- During reasoning when an agent explicitly asks for relevant historical context

### Decay

Confidence should decrease over time when a memory is not used.

A simple strategy is:

- Start at `1.0`
- Decay confidence based on age and lack of access
- Slow decay for frequently accessed memories
- Allow confidence to recover when a memory is recalled or updated successfully

This keeps stale guidance from crowding out newer information.

### Pruning

The server should garbage-collect memories that are no longer worth keeping.

Pruning candidates include:

- Memories past `expires_at`
- Memories whose confidence has reached zero
- Duplicate or superseded memories linked by `refines` or `contradicts`

Pruning should run as a scheduled maintenance step or at safe lifecycle points.

### Conflict Resolution

Conflicts are expected in long-lived memory systems.

If two memories contradict each other:

- Prefer the newer memory when timestamps clearly indicate replacement
- Prefer the higher-confidence memory when recency is ambiguous
- Preserve the older memory temporarily if auditability matters
- Link the pair with `relation_type = 'contradicts'`

This allows recall logic to suppress stale guidance without losing history.

---

## 6. Integration with Hooks

Hooks are the main way to make memory automatic rather than manual.

### `SessionStart`

Load relevant context when a session begins.

```text
memory_recall(subject=current_project)
```

Typical usage:

- Preload repo conventions
- Rehydrate branch or issue-specific decisions
- Load stable preferences for the active user or project

### `SessionEnd`

Persist what the session learned before termination or rotation.

Typical usage:

- Store key decisions
- Save durable discoveries worth carrying forward
- Persist unresolved blockers in a form the next session can recall

```text
memory_store(category="decision", subject="current_project", content="Adopt SQLite for durable local memory.", source="session_end")
```

### `PostToolUse`

Store reusable error and recovery knowledge after tools complete.

Typical usage:

- Capture recurring failure signatures
- Store known fixes for common build or environment issues
- Record patterns for a lightweight error knowledge base

```text
memory_store(category="fact", subject="error-kb", content="dotnet restore may fail until private feed auth is refreshed.", source="PostToolUse:powershell")
```

### `PreToolUse`

A future extension can query memory before risky actions.

Example uses:

- Check for known tool-specific failure patterns
- Surface warnings tied to the active repo, branch, or environment
- Inject relevant conventions before destructive commands

---

## 7. Retrieval Model

Baseline retrieval should prefer deterministic methods first:

1. Exact subject match
2. Category filter
3. Keyword search over `content` and `source`
4. Ranking by confidence, recency, and access frequency

This keeps the default implementation transparent and easy to debug.

For example, the server can issue SQL such as:

```sql
SELECT id, category, subject, content, confidence
FROM memories
WHERE subject = 'testing'
  AND category = 'convention'
  AND content LIKE '%before merge%'
ORDER BY confidence DESC, last_accessed DESC, access_count DESC
LIMIT 10;
```

---

## 8. Local Embeddings Extension (Optional)

If semantic recall is needed, the schema can be extended with embeddings.

### Schema Extension

```sql
ALTER TABLE memories ADD COLUMN embedding BLOB;
```

### Suggested Stack

- `sqlite-vec` for vector storage and similarity search
- `nomic-embed-text` served by Ollama for 768-dimensional local embeddings
- Keyword and SQL fallback when embeddings are unavailable or disabled

### Benefit

This enables prompts such as:

```text
find memories similar to "build failures caused by stale caches"
```

Semantic recall is helpful when the agent knows the idea it wants but not the exact stored wording.

The extension should remain optional so the baseline server still works in offline, low-dependency, or restricted environments.

---

## 9. Security Considerations

Persistent memory must be treated as sensitive operational data even when it does not contain secrets.

Required safeguards:

- Never store secrets, tokens, passwords, API keys, or credentials
- Sanitize content before storage and strip PII if configured
- Restrict database file permissions so it is readable only by the current user
- Support encryption at rest for enterprise environments
- Keep provenance so suspicious or low-trust memories can be audited or removed

Recommended operational controls:

- Maintain an allowlist of safe categories
- Run secret scanning before writes are committed to the database
- Separate personal memory from repo-shared memory if multi-user support is added
- Log forget and update operations when compliance requires traceability

---

## 10. Operational Notes

A practical implementation can remain small:

- One SQLite database file per user, workspace, or repo scope
- MCP server process exposes the memory tools over a local transport
- Hooks call the MCP tools rather than reading the database directly
- Maintenance tasks periodically decay confidence and prune stale records

This gives Base Coat agents a durable, local-first memory layer that is simple enough to deploy broadly while still leaving room for semantic search and richer relation handling later.
