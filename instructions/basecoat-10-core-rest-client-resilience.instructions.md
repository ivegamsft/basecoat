---
description: "Use when building or reviewing HTTP client code that calls external APIs. Covers timeouts, retries, 429 handling, circuit breakers, and structured failure logging."
applyTo: "**/*.cs,**/*.ts,**/*.py,**/*.go"
---

# REST Client Resilience

Use this instruction when writing or reviewing code that makes HTTP calls to external services, APIs, or microservice endpoints.

## Expectations

- Every HTTP client must have an **explicit timeout** — never rely on platform defaults.
- Retries must use **exponential backoff with jitter** — not fixed intervals.
- `429 Too Many Requests` responses must be handled by respecting the `Retry-After` header.
- Concurrent outbound requests must be **bounded** by a semaphore or connection pool limit.
- Token refresh must be handled transparently — callers should not retry on `401` manually.
- All failures must produce **structured logs** with correlation ID, URL, status code, and duration.

## Timeout Configuration

```csharp
// C# — always set a timeout
var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

// Per-request timeout with CancellationToken
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
var response = await client.GetAsync(url, cts.Token);
```

```typescript
// TypeScript — AbortController for per-request timeout
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 10_000);
const response = await fetch(url, { signal: controller.signal });
clearTimeout(timeout);
```

## Retry with Exponential Backoff

```csharp
// C# with Polly
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .OrResult<HttpResponseMessage>(r => r.StatusCode == HttpStatusCode.TooManyRequests
        || r.StatusCode >= HttpStatusCode.InternalServerError)
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: (attempt, result, _) =>
        {
            // Respect Retry-After header on 429
            if (result.Result?.Headers.RetryAfter?.Delta is TimeSpan delta)
                return delta;
            // Exponential backoff with jitter
            var baseDelay = TimeSpan.FromSeconds(Math.Pow(2, attempt));
            var jitter = TimeSpan.FromMilliseconds(Random.Shared.Next(0, 1000));
            return baseDelay + jitter;
        },
        onRetryAsync: (outcome, delay, attempt, _) =>
        {
            Log.Warning("Retry {Attempt} after {Delay}ms for {Url}: {Status}",
                attempt, delay.TotalMilliseconds, outcome.Result?.RequestMessage?.RequestUri,
                outcome.Result?.StatusCode);
            return Task.CompletedTask;
        });
```

```typescript
// TypeScript — manual retry with backoff
async function fetchWithRetry(url: string, options?: RequestInit, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const response = await fetch(url, options);

    if (response.ok) return response;

    if (response.status === 429 || response.status >= 500) {
      if (attempt === maxRetries) throw new Error(`Failed after ${maxRetries} retries`);
      const retryAfter = response.headers.get("Retry-After");
      const delay = retryAfter
        ? parseInt(retryAfter, 10) * 1000
        : Math.pow(2, attempt) * 1000 + Math.random() * 1000;
      await new Promise((r) => setTimeout(r, delay));
      continue;
    }

    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
}
```

## Concurrency Control

Bound outbound requests to prevent overwhelming downstream services:

```csharp
// C# — SemaphoreSlim to limit concurrent calls
private static readonly SemaphoreSlim _throttle = new(maxCount: 10);

public async Task<T> CallApiAsync<T>(string url)
{
    await _throttle.WaitAsync();
    try { return await _client.GetFromJsonAsync<T>(url); }
    finally { _throttle.Release(); }
}
```

```typescript
// TypeScript — p-limit for concurrency control
import pLimit from "p-limit";
const limit = pLimit(10);
const results = await Promise.all(urls.map((url) => limit(() => fetch(url))));
```

## Structured Failure Logging

Every failed HTTP call must log these fields:

| Field | Example |
|-------|---------|
| `correlationId` | `"x-req-abc123"` |
| `url` | `"https://api.example.com/users"` |
| `method` | `"GET"` |
| `statusCode` | `429` |
| `durationMs` | `2340` |
| `retryAttempt` | `2` |
| `errorCategory` | `"throttled"` / `"timeout"` / `"server_error"` |

```csharp
Log.Warning("HTTP {Method} {Url} failed: {Status} after {Duration}ms (attempt {Attempt}, {Category})",
    request.Method, request.RequestUri, response.StatusCode, elapsed.TotalMilliseconds, attempt, category);
```

## Anti-Patterns

- **No timeout**: HTTP call hangs indefinitely, exhausting thread pool.
- **Fixed-interval retry**: `Thread.Sleep(5000)` between retries — causes thundering herd.
- **Ignoring 429**: retrying immediately on rate limit without `Retry-After`.
- **Unbounded concurrency**: `Parallel.ForEach` with no `MaxDegreeOfParallelism`.
- **Swallowing errors**: `catch (Exception) { }` with no logging.
- **Retrying non-idempotent calls**: POST/PUT with side effects must not auto-retry without idempotency keys.

## Review Lens

- Does every `HttpClient` / `fetch` call have an explicit timeout?
- Are retries using exponential backoff with jitter, not fixed intervals?
- Is the `Retry-After` header respected on 429 responses?
- Are concurrent outbound requests bounded?
- Do failure logs include correlation ID, URL, status, duration, and error category?
- Are non-idempotent mutations (POST, DELETE) excluded from automatic retry?
