---
name: service-bus-migration
compatibility: [github-copilot-cli]
title: MSMQ to Azure Service Bus Migration
description: "Use when migrating enterprise messaging from MSMQ to Azure Service Bus with phased cutover and resilience patterns. USE FOR: map MSMQ queues to topics and subscriptions, design hybrid bridge for zero-downtime cutover, convert binary messages to JSON, implement retry and dead-letter handling, plan Service Bus migration phases. DO NOT USE FOR: greenfield Kafka architecture, unrelated REST API migration."
category: data
---
# Service Bus Migration Skill

Migrate enterprise messaging from MSMQ to Azure Service Bus using phased cutover, hybrid bridge, and resilience patterns.

## Reference Files

| File | Contents |
|------|----------|
| [`references/migration-patterns.md`](references/migration-patterns.md) | Lift-and-shift vs gradual migration, topic/subscription mapping, serialization |
| [`references/dead-letter-and-retry.md`](references/dead-letter-and-retry.md) | Dead-letter queue processing, exponential backoff, error classification |
| [`references/advanced-patterns.md`](references/advanced-patterns.md) | Outbox pattern, hybrid bidirectional bridge, control plane, cutover checklist |

## Migration Phases

| Phase | Mode | Action |
|-------|------|--------|
| 0 | MSMQ Only | Baseline — no changes |
| 1 | MSMQ Primary → SB Secondary | Shadow writes, validate conversions |
| 2 | SB Primary → MSMQ Secondary | Safe fallback, monitor closely |
| 3 | Service Bus Only | Decommission MSMQ |

## Best Practices

- Use the **Outbox Pattern** for guaranteed delivery without distributed transactions
- Classify errors: transient (retry) vs permanent (dead-letter)
- Use feature flags for staged routing transitions
- Preserve correlation IDs through all serialization conversions
