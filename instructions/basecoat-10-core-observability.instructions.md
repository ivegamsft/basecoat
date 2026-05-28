---
description: >
  OpenTelemetry instrumentation standards — trace context propagation,
  structured logging schema, metrics naming, and dashboard patterns.
applyTo: "**/*.{cs,ts,tsx,js,jsx,py,go,java,json,yml,yaml}"
---

# Observability Standards

## When Instrumenting Applications

Every application must emit **logs, metrics, and traces** following these standards.

## Rules

- Instrument logs, metrics, and traces together so incidents can be correlated without guesswork.
- Propagate W3C trace context across every inbound and outbound boundary.
- Keep logs structured, redact secrets, and include correlation identifiers on every request path.
- Define production sampling and dashboard expectations before rollout, not after the first incident.

## Trace Context Propagation

Always propagate W3C Trace Context across service boundaries:

- **Inbound:** Extract `traceparent` / `tracestate` from request headers.
- **Outbound:** Inject trace context into all downstream calls.
- **Logging:** Include `trace_id` and `span_id` in every log line.
- **Sampling:** Respect `trace_flags` — don't sample everything in production.

Standard header: `traceparent: "00-<trace_id>-<span_id>-<trace_flags>"`

See [tracing-and-logging.md](references/observability/tracing-and-logging.md) for Python/Flask OTEL examples, structured log schema, and logging anti-patterns.

## Structured Logging

All logs must be structured JSON — never free text. Required fields per log line:

- `timestamp`, `level`, `logger`, `message`
- `trace_id`, `span_id`, `request_id` (for correlation)
- `context.service`, `context.environment`, `context.version`
- `http.method`, `http.path`, `http.status_code`, `http.duration_ms`

**DO NOT** log passwords, tokens, credit cards, SSNs, or raw request/response bodies.

## Examples

### Example structured log event

```json
{
  "timestamp": "2026-05-10T18:24:00Z",
  "level": "error",
  "message": "Downstream payment request failed",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "context": {
    "service": "checkout-api",
    "environment": "prod",
    "version": "1.12.0"
  }
}
```

### Example metric names

```text
http.request.count
database.query.duration
cache.hit.count
```

## Metrics Naming

Format: `<namespace>.<component>.<metric_name>.<unit>`

Examples: `http.request.count`, `http.request.duration`, `database.query.duration`, `cache.hit.count`

Label every metric with relevant dimensions: `method`, `path`, `status_code`, `operation`, `table`.

See [metrics-and-sampling.md](references/observability/metrics-and-sampling.md) for full naming reference, label conventions, and sampling strategies.

## Sampling Strategy (Production)

- **100% sample errors** — never drop error spans.
- **100% sample slow requests** (> 1 second).
- **5–10% sample normal requests** — reduces cost, preserves signal.
- Advanced: use tail sampling to decide post-collection (most flexible, higher memory overhead).

## Dashboard Requirements

Every service must have:

1. **Service Overview:** Request rate, P50/P95/P99 latency, error rate, top slow/error endpoints.
2. **Application:** HTTP breakdown, DB query performance, cache hit ratio, external dependencies.
3. **Infrastructure:** CPU, memory, disk I/O, network I/O, container restarts.
4. **SLO Compliance:** SLO target %, current compliance %, error budget remaining, burn rate.

See [dashboards-and-compliance.md](references/observability/dashboards-and-compliance.md) for log aggregation architecture, correlation ID pattern, and SOC2/HIPAA/PCI-DSS mappings.

## Reference Files

| File | Contents |
|---|---|
| [tracing-and-logging.md](references/observability/tracing-and-logging.md) | W3C trace context, OTEL setup, log schema, anti-patterns |
| [metrics-and-sampling.md](references/observability/metrics-and-sampling.md) | Naming format, label conventions, sampling strategies |
| [dashboards-and-compliance.md](references/observability/dashboards-and-compliance.md) | Dashboard specs, log aggregation, compliance mappings |

## See Also

- `security-monitoring.instructions.md` — Security event log schema and SIEM integration.
- `development.instructions.md` — Application development standards including error handling.
