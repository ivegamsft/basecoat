# Build Master Policy Matrix

## Break-fix eligibility

| Failure class | Default action | Cloud auto-fix allowed | Notes |
| --- | --- | --- | --- |
| CI configuration drift | dispatch fix PR | yes | low-risk config-only changes |
| Deterministic test path fix | dispatch fix PR | yes | requires bounded file scope |
| Flaky test quarantine | dispatch fix PR | yes | must include follow-up issue |
| Dependency pin rollback | dispatch fix PR | yes | patch/minor only |
| Secret/auth/security boundary failure | pause + escalate | no | human approval required |
| Infra provisioning/runtime access failure | pause + escalate | no | treat as high risk |

## Retry and revert policy

| Policy item | Default | Escalation |
| --- | ---: | --- |
| Automated fix retries per incident | 2 | pause lane + blocking issue |
| Consecutive failed fix PRs | 2 | trigger auto-revert candidate + human review |
| Time in `paused` before owner page | 30 min | escalate to incident owner |

## Merge continuity policy

1. Serialized merges within each lane.
2. Unaffected lanes continue unless global risk rule triggers hold.
3. Branch protection and required checks always gate merges.
4. All repairs and rollbacks are PR-based and auditable.
