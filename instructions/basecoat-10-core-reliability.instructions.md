---
description: "Use when changing code paths where uptime, retries, background work, or dependency failures matter. Covers common reliability and operability best practices."
applyTo: "**/*.{cs,ts,tsx,js,jsx,py,go,java,rb,ps1,json,yml,yaml}"
---

# Reliability Standards

Use this instruction when a change depends on external systems, asynchronous work, or long-running processes.

## Rules

- Bound remote calls with timeouts, cancellation, and explicit failure handling.
- Retry only transient failures, with capped attempts and backoff.
- Make background work idempotent or persist enough state to resume safely after crashes.
- Emit logs and metrics that let responders reconstruct partial failure paths.

## Expectations

- Make failure modes visible and bounded with timeouts, cancellation, and clear error handling.
- Use retries only for transient failures, with limits and backoff.
- Design background and scheduled work to be idempotent when practical.
- Emit enough logs or telemetry to reconstruct what happened during failures.
- Avoid partial writes or split-brain behavior when multiple systems must stay consistent.
- Prefer health checks and graceful shutdown behavior for services that stay running.

## Examples

### Example bounded outbound call

```ts
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 3000);

try {
  return await fetch(url, { signal: controller.signal });
} finally {
  clearTimeout(timeout);
}
```

### Example idempotent background processing

```text
Before writing results, check whether jobId=1234 was already completed.
If it was, return success without applying the write a second time.
```

## Review Lens

- What happens when a dependency is slow, unavailable, or returns bad data?
- Can the operation be retried safely?
- Is there enough observability to diagnose a production issue without reproducing locally?
- Does the change create hidden coupling between independent systems?
