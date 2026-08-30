# Middleware Development Agent — Detail Reference

Full patterns for `agents/basecoat-10-core-middleware-dev.agent.md`.

## Resilience Patterns

### Retry with backoff

- Retry transient failures using exponential backoff with jitter.
- Define a maximum retry count. Never retry indefinitely.
- Log each retry attempt with the attempt number, delay, and error reason.

### Circuit breaker

- Wrap calls to unstable downstream services in a circuit breaker.
- Define thresholds: failure rate or consecutive failures that open the circuit.
- Log circuit state transitions (closed → open → half-open → closed).

### Dead letter queue (DLQ)

- Route messages that exceed the retry limit to a DLQ rather than discarding them.
- Include the original message, failure reason, retry count, and timestamp on every DLQ entry.
- Monitor the DLQ — an accumulating DLQ is an operational alert.

### Idempotency

- Assign a unique `messageId` or `idempotencyKey` to every message at the producer.
- Consumers must check for duplicate delivery and skip already-processed messages.
- Use a deduplication log or idempotency store with appropriate TTL.

### Outbox pattern

- When a service must publish a message as part of a database transaction, write to an outbox table inside the same transaction.
- A separate relay process reads the outbox and publishes to the broker.
- This prevents the dual-write problem where the database commits but the message is never sent.

## Message Broker Agnostic Patterns

These patterns apply regardless of the broker (Kafka, Azure Service Bus, RabbitMQ, Amazon SQS, or any other):

- **Producers** set a `messageId`, `correlationId`, `timestamp`, `eventType`, and schema version on every message.
- **Consumers** are idempotent and log the `correlationId` for every message processed.
- **Schemas** are versioned and backward-compatible. Additive changes (new optional fields) are non-breaking. Removal or type changes require a new schema version.
- **Partitioning/ordering** is only guaranteed within a partition key. Do not assume global ordering.
- **Poison messages** (messages that always fail processing) go to the DLQ after max retries.

## API Gateway Concerns

- Route definitions declare their auth requirement explicitly. No route is implicitly public.
- Apply rate limiting per consumer identity, not per IP. Document the limit in the route spec.
- Request/response transformation is done in the gateway adapter layer, not inside downstream services.
- The gateway must propagate `correlationId` and `traceparent` headers downstream on every request.
- Auth delegation: the gateway validates tokens, strips client-supplied claim headers, and
  forwards verified claims only over an authenticated private channel or signed assertion.
  Services trust those claims only after enforcing that gateway trust boundary.

## Contract Testing

- Use consumer-driven contracts: the consumer defines what it needs, the provider verifies it can supply that.
- Run contract tests in CI on both the consumer and provider pipelines.
- Any schema change that breaks an existing contract requires a version bump and consumer coordination.

## Observability

- Propagate distributed trace context (`traceparent`, `tracestate`, or equivalent) across every hop.
- Log message processing events: received, validated, processed, failed, retried, dead-lettered.
- Include `correlationId`, `messageId`, `eventType`, and `processingDurationMs` in processing log entries.
- Emit metrics: message throughput, processing latency, error rate, DLQ depth, circuit breaker state.
- Structured (JSON) logs only. No plain-text log lines.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Tech Debt]`
- **Base labels:** `tech-debt,middleware,reliability`
- **Category options:** `<missing retry | no DLQ | synchronous call should be async | missing idempotency>`
- **File:** `<path/to/file.ext>`

| Finding | Labels |
|---|---|
| Integration call with no retry logic | `tech-debt,middleware,reliability` |
| Message consumer with no dead letter routing | `tech-debt,middleware,reliability` |
| Synchronous HTTP call for a fire-and-forget interaction | `tech-debt,middleware,reliability` |
| Message handler with no idempotency check | `tech-debt,middleware,reliability` |
| Missing distributed trace propagation across a service boundary | `tech-debt,middleware,observability` |
