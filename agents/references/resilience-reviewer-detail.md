# Resilience Reviewer — Pattern Detail

Supporting detail for [`agents/basecoat-90-quality-resilience-reviewer.agent.md`](../basecoat-90-quality-resilience-reviewer.agent.md).

## Core Patterns

### 1. Circuit Breakers

- External calls should fail fast when an upstream is unhealthy.
- Confirm thresholds and reset windows are set intentionally.
- Ensure fallback behavior exists for business-critical paths.

### 2. Timeout Hierarchy

- Enforce decreasing timeout budgets downstream.
- Verify parent calls do not wait longer than child calls.
- Confirm defaults are not "infinite" in clients or SDKs.

### 3. Bulkheads

- Validate pool isolation by dependency/service class.
- Check per-pool queue limits and overload behavior.
- Ensure one dependency can't starve unrelated workloads.

### 4. Retries

- Retry only transient classes (timeouts, 429/5xx, transport failures).
- Use bounded exponential backoff plus jitter.
- Never retry permanent client errors (4xx contract/auth failures).

### 5. Graceful Degradation

- Validate fallback behavior for critical user journeys.
- Prefer stale/cache/default responses over total request failure.
- Tag degraded responses to support monitoring and postmortem analysis.

### 6. Load Shedding

- Verify overload controls reject low-priority work first.
- Ensure high-priority traffic preserves a reserved budget.
- Confirm "fail fast" behavior protects latency and queue depth.

## Review Checklist

```yaml
Resilience Pattern Audit:
  Circuit Breakers:
    - [ ] Wrap all external calls
    - [ ] Tune thresholds and reset windows
  Timeouts:
    - [ ] Every call has explicit timeout
    - [ ] Timeouts decrease downstream
  Bulkheads:
    - [ ] Isolated pools and bounded queues
  Retries:
    - [ ] Transient-only retries with backoff+jitter
  Degradation:
    - [ ] Fallback path for critical dependencies
  Load Shedding:
    - [ ] Priority-aware rejection under saturation
```

## Integration Points

- **SRE Engineer** agent — SLO/error budget implications
- **Chaos Engineer** agent — Resilience testing (intentional failures)
- **Performance Analyst** agent — Timeout tuning based on metrics
- **Backend Dev** agent — Implementation guidance

## Standards & References

- [Release It! (2nd Edition)](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [Resilience4j Documentation](https://resilience4j.readme.io/)
- [AWS Well-Architected Framework — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [NIST SP 800-34 — Contingency Planning](https://doi.org/10.6028/NIST.SP.800-34r1)
