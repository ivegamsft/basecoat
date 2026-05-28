# Memory Design

Base Coat uses a five-layer memory hierarchy that gives every agent session
fast access to the most relevant knowledge while keeping cold or historical
context out of the token budget.

## Layer Overview

| Layer | Name | Where stored | Loaded when |
|-------|------|-------------|-------------|
| L0 | Agent frontmatter | `agents/*.agent.md` | Always — compiled into agent definition |
| L1 | Scoped instructions | `instructions/*.instructions.md` | Per `applyTo` glob match at session start |
| L2 | Hot cache index | `instructions/memory-index.instructions.md` | Every session start (L1 rule) |
| L3 | Session store | `session_store_sql` (DuckDB) | On demand — cross-session queries |
| L4 | Long-term memory | `store_memory` tool + `docs/` | On demand — persistent facts |

### Shared tiers (multi-repo)

| Layer | Name | Where stored |
|-------|------|-------------|
| L2s | Shared hot index | `basecoat-memory/hot-index.md` (synced via `sync-shared-memory.ps1`) |
| L3s | Shared domain cache | `basecoat-memory/memories/<domain>.md` |

---

## Layer Details

### L0 — Agent Frontmatter

Critical, always-on context embedded in every agent definition:

```yaml
---
name: solution-architect
description: >
  Solution architecture agent for system design, C4 diagrams, ADRs,
  technology selection, and cross-cutting concerns.
---
```

Facts at L0 are read before any other context. Keep them minimal — only
invariants that never change across sessions or repos.

**Promotion threshold:** A pattern referenced in > 50 % of production sessions.

### L1 — Scoped Instructions

Instruction files with `applyTo` globs. Loaded automatically when the active
file matches. No token cost for non-matching sessions.

```yaml
---
applyTo: "**/*.ts"
description: "TypeScript coding conventions"
---
```

**Promotion threshold:** Pattern accessed in ≥ 5 consecutive sessions.

### L2 — Hot Cache Index

`instructions/memory-index.instructions.md` — loaded at every session start
via a broad `applyTo: "**/*"` rule. Contains:

- Execution path routing decisions (fast-path vs. deep-reasoning)
- Pattern bundle catalog (skill clusters by domain)
- Turn budget guidance
- Pointers to L3 / L4 for cold patterns

**Promotion threshold:** Pattern accessed ≥ 3 times from L3/L4.

**Heat levels:** cold (0–2 accesses) → warm (3–9) → hot (10+).

### L3 — Session Store

`session_store_sql` (DuckDB) stores all session turns, file changes, tool
calls, and agent outputs across the full session history of the repo.

Query with the `session_store_sql` tool. Use it to:

- Recall prior approaches to a problem
- Trace which sessions touched a file
- Find PR/issue associations

### L4 — Long-Term Memory

`store_memory` tool writes facts to the Copilot memory store. Use for:

- Codebase conventions learned during a session
- Build/test/lint commands discovered to work
- Architectural decisions that affect future tasks

---

## Promotion Ladder

```text
L4 store_memory  ──(3× access)──▶  L2 hot-cache entry
L3 session_store ──(3× access)──▶  L2 hot-cache entry
L2 hot-cache     ──(5 sessions)──▶  L1 scoped instruction
L1 instruction   ──(50% sessions)─▶  L0 agent frontmatter
```

Demotion happens automatically: hot-cache entries not accessed in 10+ sessions
are removed on next review. L4 facts decay after ~30 days if not re-stored.

---

## Turn Budget Protocol

Each session has a soft token budget. The memory hierarchy enforces it:

| Phase | Action |
|-------|--------|
| Session start | Load L0+L1+L2 (always in budget) |
| First tool call | Route via L2 fast-path catalog |
| Cache miss | Query L3 session store (selective) |
| Deep miss | Fetch L4 doc or prompt `store_memory` recall |
| Over budget | Summarize and drop cold L3 results |

---

## Failure and Success Protocols

**On session success** — store durable facts:

- Patterns that worked (commands, approaches, file paths)
- Decisions made and their rationale

**On session failure** — record blockers:

- What failed and why (error text, root cause hypothesis)
- What was tried and ruled out
- Unresolved dependencies (human actions needed)

**On context overflow** — graceful degradation:

1. Drop cold L3 query results first
2. Summarize L4 doc excerpts to key points
3. Keep L0/L1/L2 intact — never drop hot cache

---

## Design Principles

1. **Hot path first** — L2 routes 80 % of requests without L3/L4 calls
2. **Lazy loading** — cold tiers load only on cache miss
3. **Decay by access** — unused entries do not persist forever
4. **Shared knowledge separates from personal** — L2s/L3s are org-scoped; L3/L4 are session-scoped
5. **Humans own L0** — agent frontmatter is reviewed and merged, never auto-promoted
