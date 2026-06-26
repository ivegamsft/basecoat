---
name: cqrs-event-sourcing
compatibility: [github-copilot-cli]
description: "CQRS and Event Sourcing patterns for scalable, auditable distributed systems with command models, event stores, and read projections. USE FOR: design CQRS architecture for a service, implement event sourcing for audit history, separate command and query models, plan read model projections and replay, add saga orchestration for eventual consistency. DO NOT USE FOR: simple CRUD app design, single-table admin tools, basic ORM mapping questions."
category: architecture
---
# CQRS & Event Sourcing Patterns

Patterns for implementing CQRS and Event Sourcing in distributed systems.

## Quick Navigation

| Reference | Contents |
|---|---|
| [references/command-side.md](references/command-side.md) | Commands, command handlers, aggregate design |
| [references/event-sourcing.md](references/event-sourcing.md) | Event store, aggregate reconstruction, snapshots, versioning |
| [references/read-side.md](references/read-side.md) | Queries, read models, event subscribers, eventual consistency |
| [references/sagas-operations.md](references/sagas-operations.md) | Saga pattern, event replay, monitoring, disaster recovery |

## Core Flow

```text
User → Command → Handler → Event Store → Events → Event Bus
                                                       ↓
                                               Event Handlers → Read Models → User
```

## When to Use

Use when an audit trail, independent read/write scaling, or multiple read-optimized views are
needed. Avoid for simple CRUD with uniform load.
