---
name: domain-driven-design
title: Domain-Driven Design & CQRS Patterns
description: "Domain-driven design guidance covering bounded contexts, aggregates, event sourcing, CQRS, and saga coordination in complex domains. USE FOR: model bounded contexts and aggregates, design domain events and invariants, apply DDD to microservice boundaries, implement saga orchestration for business workflows, combine DDD with CQRS patterns. DO NOT USE FOR: simple CRUD scaffolding, basic SQL report queries, generic UI styling tasks."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  domain: architecture
  category: "Architecture & Design"
  maturity: production
  audience: [architect, backend-engineer]
allowed-tools: [python, javascript, java]
---

# Domain-Driven Design Skill

Production patterns for DDD, CQRS, Event Sourcing, and Saga implementation.

## Reference Files

| File | Contents |
|------|----------|
| [`references/patterns.md`](references/patterns.md) | Aggregate/value-object patterns, event sourcing, CQRS command/query split, saga compensation |

## Core Concepts

| Concept | Summary |
|---------|---------|
| Bounded Context | Explicit model boundary; each context owns its domain language |
| Aggregate | Consistency boundary; root enforces invariants and emits events |
| Domain Event | Immutable fact describing a state change (past tense) |
| CQRS | Commands modify state; queries read from separate read models |
| Event Sourcing | State reconstructed by replaying the immutable event log |
| Saga | Coordinates multi-step workflows with compensating transactions |

## References

- [Domain-Driven Design](https://www.domainlanguage.com/ddd/)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
