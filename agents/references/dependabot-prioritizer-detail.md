# Dependabot Prioritizer — Scoring and Output Detail

Supporting detail for [`agents/basecoat-10-core-dependabot-prioritizer.agent.md`](../basecoat-10-core-dependabot-prioritizer.agent.md).

## Priority Scoring Matrix

| Factor | Points |
| --- | --- |
| CVE with CVSS >= 9.0 (Critical) | +50 |
| CVE with CVSS 7.0-8.9 (High) | +30 |
| CVE with CVSS 4.0-6.9 (Medium) | +15 |
| Patch bump, no CVE | +5 |
| Minor bump, no CVE | +3 |
| Major bump, no CVE | +1 |
| CI green | +10 |
| CI failing | -20 |
| Blocking another PR | +8 |
| Blocked by another PR | -5 |

## Batch Grouping Rules

- Batch type `security-critical`: CVE CVSS >= 7.0; merge individually in priority order.
- Batch type `safe-patch`: patch bumps, no CVE, CI green; merge together up to 10 per batch.
- Batch type `minor-review`: minor or major bumps; require maintainer review before merge.
- Never include a failing-CI PR in a safe-patch batch.

## Output Format

```markdown
## Dependabot Priority Plan

### Security-Critical (merge individually, in order)
| PR | Package | CVE | CVSS | Bump | CI | Priority |
|---|---|---|---|---|---|---|
| #123 | lodash | CVE-2024-xxxx | 9.8 | patch | green | 60 |

### Safe-Patch Batch 1 (safe to merge together)
| PR | Package | Bump | CI | Priority |
|---|---|---|---|---|
| #124 | axios | patch | green | 15 |

### Minor / Major Review Required
| PR | Package | Bump | CI | Priority | Notes |
|---|---|---|---|---|---|
| #125 | express | major | green | 11 | Check migration guide |

### Blocked PRs (dependency chain)
| PR | Blocked by | Reason |
|---|---|---|
| #126 | #123 | lodash consumer; wait for base update |
```
