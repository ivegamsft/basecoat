# Self-Healing CI — Remediation Strategy Detail

Supporting detail for [`agents/basecoat-60-workflow-self-healing-ci.agent.md`](../basecoat-60-workflow-self-healing-ci.agent.md).

## Remediation Strategies

### Retry with Exponential Backoff

Use for transient timeout/network/throttle failures. Apply bounded retries with jitter and clear attempt annotations.

### Dependency Cache Reset

Use for checksum/resolution issues. Clear package cache, refresh lock state only when policy allows, reinstall, and verify.

### Build Cache Invalidation

Invalidate affected cache layers first; use full cache purge only with explicit approval.

### Environment Reset

Reset stale runtime state, validate disk/memory thresholds, and retry in clean environment.

### Flaky Test Quarantine

File issue, quarantine per policy, rerun without quarantined tests, and track flake metrics.

### Dependency Version Negotiation

Resolve transitive conflicts with minimal compatible version changes; open PR for maintainer review.

## Common PaaS Startup Signals (Azure App Service)

| Signal | Typical Action |
| --- | --- |
| `Container didn't respond to HTTP pings` | Raise startup timeout and verify app binds to platform port |
| repeated `Health check failed` | Ensure health endpoint returns HTTP 200 without auth |
| `Swap operation timed out` | Configure warm-up path/status and slot initialization |
| `ENOENT` startup errors | Inspect build/deploy artifact for missing outputs |

## Integration Points

- CI platforms: GitHub Actions, Azure Pipelines, GitLab CI, Jenkins.
- Telemetry: OpenTelemetry, Application Insights, Datadog/New Relic.
- Collaboration: GitHub Issues/PRs, Slack/email escalation, PR/job comments.
- External systems: package registries, security advisories, git hosting APIs.

## Configuration

```yaml
agent:
  name: self-healing-ci
  enabled: true
  retry:
    max_attempts: 3
    initial_backoff_seconds: 2
    max_backoff_seconds: 60
    jitter_percent: 20
  cache:
    enable_selective_invalidation: true
    min_free_disk_mb: 100
  flaky_tests:
    failure_rate_threshold: 0.8
    pass_on_retry_threshold: 0.5
    quarantine_enabled: true
```

## Metrics & Observability

Track autonomous recovery rate, MTTR, flaky-test prevalence, cache efficiency, dependency conflict
frequency, and false-positive remediations.

## Future Enhancements

- learned failure signatures,
- cross-repo flaky test intelligence,
- predictive cache invalidation,
- remediation cost optimization.
