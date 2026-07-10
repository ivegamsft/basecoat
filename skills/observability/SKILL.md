---
name: observability
compatibility: [github-copilot-cli]
description: "Use when adding logs, metrics, traces, or alertable telemetry to apps, services, and distributed systems. USE FOR: instrument service with OpenTelemetry, add structured logging and trace IDs, define SLI or latency metrics, trace requests across queues and APIs, improve incident debugging telemetry. DO NOT USE FOR: pure UI redesign, business analytics reporting."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Observability Skill

Instrument services with structured logs, metrics, and distributed traces to enable alerting and fast incident triage.

## Reference Files

| File | Contents |
|------|----------|
| [`references/instrumentation.md`](references/instrumentation.md) | OpenTelemetry setup (Flask/Python), log fields, metric dimensions, span attributes |

## Core Patterns

| Signal | What to Capture | Key Rule |
|--------|----------------|---------|
| Logs | State transitions, failures | Structured fields: severity, service, env, operation, trace\_id |
| Metrics | Volume, latency, errors, saturation, queue depth | Low-cardinality labels only |
| Traces | HTTP handlers, DB calls, queue consumers, 3rd-party | Attributes: route, dependency, status |

## Inputs and Outputs

- **Input**: incident symptoms, service diagrams, existing logger/metrics code, telemetry backend
- **Output**: instrumentation plans, naming conventions, example code, alert recommendations
