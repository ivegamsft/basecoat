<!-- markdownlint-disable MD041 -->
## Workflow Loop Architecture and Control Points

Visual reference for BaseCoat's recurring control loops, escalation paths, and merge pacing.

- Primary source anchors:
  - `.github/workflows/ship-it-intent-dispatch.yml` (intent dispatch and remediation)
  - `.github/workflows/validate-basecoat.yml` (verify gate: `validate-unix`, `validate-windows`, `validate-commit-messages`)
  - `.github/workflows/agent-merge.yml` (guardrails, rollback)
  - `.github/workflows/stale-management.yml` (retriage, staleness sweep)
  - `docs/operations/merge-queue-enforcement.md` (merge queue parameters)
  - `docs/agents/multi-agent-workflows.md` (fleet merge pacing)

---

## 1. Primary Workflow Loop

The core delivery cycle spans six phases. Each phase is backed by one or more workflows.
Stop conditions and timeout boundaries are marked at every exit that terminates the loop.

```mermaid
flowchart TD
    START(["Issue created / PR opened\n/ship-it comment"]) --> TRIAGE

    TRIAGE["Triage\nissue-triage.lock.yml\njob: activation"] --> TRIAGE_DEC{Priority + type\nassigned?}
    TRIAGE_DEC -->|"priority:critical / high / medium / low\ntype label applied"| IMPLEMENT
    TRIAGE_DEC -->|"Duplicate or not-planned"| STOP_TRIAGE(["Stop: Issue closed\nnot_planned"])

    IMPLEMENT["Implement\nship-it-intent-dispatch.yml\njobs: resolve-intent → dispatch-intent"] --> VERIFY

    VERIFY["Verify\nvalidate-basecoat.yml\njobs: validate-unix\n      validate-windows\n      validate-commit-messages"] --> VERIFY_DEC{All checks\npass?}
    VERIFY_DEC -->|Yes| MERGE
    VERIFY_DEC -->|"Failure (retry if budget remains)"| ESCALATE

    MERGE["Guardrails validated\nagent-merge.yml / job: guardrails\nOn pass: GitHub merge queue\nperforms squash merge"] --> MERGE_DEC{Merge\nsucceeded?}
    MERGE_DEC -->|Yes| MONITOR
    MERGE_DEC -->|"Removed from queue"| IMPLEMENT

    MONITOR["Monitor\npost-onboarding-drift-loop.yml\nrunner-health-observability.yml"] --> MONITOR_DEC{Drift or\nregression?}
    MONITOR_DEC -->|Clean| RETRIAGE
    MONITOR_DEC -->|"Regression detected"| IMPLEMENT

    RETRIAGE["Retriage\nstale-management.yml\njob: stale-sweep\n(daily at 07:00 UTC)"] --> RETRIAGE_DEC{Activity\nwithin window?}
    RETRIAGE_DEC -->|"Active (updated < 30 days)"| TRIAGE
    RETRIAGE_DEC -->|"Stale (30 days) → close (+ 14 days)"| STOP_STALE(["Stop: Auto-closed\nstate_reason=not_planned"])

    ESCALATE["Escalation Loop\n(see Diagram 2)"] --> ESCALATE_DEC{Recovered?}
    ESCALATE_DEC -->|Yes| VERIFY
    ESCALATE_DEC -->|"Hard block: gate:needs-check-in"| HUMAN_GATE(["Human Gate\nManual triage required"])
    HUMAN_GATE --> TRIAGE

    style START fill:#e1f5ff
    style STOP_TRIAGE fill:#ffccbc
    style STOP_STALE fill:#ffccbc
    style HUMAN_GATE fill:#fff9c4
    style ESCALATE fill:#f8bbd0
```

### Loop boundaries

| Phase | Entry condition | Stop / exit |
|---|---|---|
| Triage | Issue created or reopened | Closed as duplicate / not_planned |
| Implement | Type + priority label applied | — (feeds Verify) |
| Verify | PR ready for review | Hard failure → Escalation Loop |
| Merge | All required checks green | Removal from queue → re-implement |
| Monitor | Squash merge to `main` | Regression → re-implement |
| Retriage | Daily schedule | 30-day stale mark → 14-day auto-close |

---

## 2. Escalation Loop

Captures the failure → retry → fallback → human-gate path wired into
`ship-it-intent-dispatch.yml` and `agent-merge.yml`.

```mermaid
flowchart TD
    FAIL["Verify or dispatch failure"] --> RETRY_DEC{Operator retry\nbudget remaining?}
    RETRY_DEC -->|"Yes: retry_context prepared"| RETRY["Retry dispatch\nships new PR / re-run"]
    RETRY --> VERIFY2["Re-enter Verify phase\nvalidate-basecoat.yml"]
    VERIFY2 --> VERIFY2_DEC{Checks pass?}
    VERIFY2_DEC -->|Yes| RECOVERED(["Recovered\nReturn to primary loop"])
    VERIFY2_DEC -->|No| RETRY_DEC

    RETRY_DEC -->|"No: budget exhausted"| REMEDIATION["Remediation issue created\nship-it-intent-dispatch.yml\nstep: Create remediation issue\nwhen dispatch fails\nlabels: intent-control-plane, remediation"]
    REMEDIATION --> FALLBACK_DEC{"Rollback available?\nagent-merge.yml\ninput: rollback_ref"}
    FALLBACK_DEC -->|"Yes: rollback_apply=true"| ROLLBACK["Rollback applied\nagent-merge.yml\njob: rollback-apply\nCreates revert commit\npushes to origin"]
    ROLLBACK --> HUMAN(["Human Gate\ngate:needs-check-in applied\nManual review + re-triage"])
    FALLBACK_DEC -->|"No rollback ref"| HUMAN

    HUMAN --> RESUME{Decision?}
    RESUME -->|"Reopen + re-triage"| RECOVER2(["Return to Triage phase"])
    RESUME -->|"Close as not_planned"| TERMINAL(["Stop: Closed"])

    style FAIL fill:#ffccbc
    style REMEDIATION fill:#f8bbd0
    style HUMAN fill:#fff9c4
    style RECOVERED fill:#c8e6c9
    style RECOVER2 fill:#c8e6c9
    style TERMINAL fill:#ffccbc
```

### Control points

| Signal | Trigger | Action |
|---|---|---|
| `steps.dispatch.outcome == 'failure'` | `ship-it-intent-dispatch.yml` | Create or update remediation issue with `intent-control-plane` + `remediation` labels |
| `rollback_ref` input provided | `agent-merge.yml` | Generate rollback patch |
| `rollback_apply=true` | `agent-merge.yml` job `rollback-apply` | Create revert commit and push to origin |
| `gate:needs-check-in` label | Any gate decision | Pause loop; require human triage |
| `gate:no-tests` label | Queue gate | Hold PR; request test coverage before re-queue |

---

## 3. Merge / Queue Loop

Serialized merge pacing from the [merge queue enforcement policy](../operations/merge-queue-enforcement.md).
Parameters: `max_entries_to_merge=1`, `grouping_strategy=headCommit`, merge method `squash`.

```mermaid
flowchart TD
    PR_OPEN["PR opened / pushed"] -->     CHECKS["Required checks run\n(1) validate-commit-messages\n(2) validate-unix\n(3) validate-windows\n(validate-basecoat.yml)"]
    CHECKS --> CHECKS_DEC{All checks\npass?}
    CHECKS_DEC -->|No| FIX["Author fixes + pushes\n(re-enters at PR_OPEN)"]
    FIX --> PR_OPEN
    CHECKS_DEC -->|Yes| APPROVAL{1 approving\nreview?}
    APPROVAL -->|No| WAIT_REVIEW["Await reviewer\n(reviewer-autoassign.yml)"]
    WAIT_REVIEW --> APPROVAL
    APPROVAL -->|Yes| QUEUE["Enter merge queue\n(grouping: headCommit)"]

    QUEUE --> BUILD["Build merge candidate\nPR commits + main HEAD"]
    BUILD --> QUEUE_CHECKS["Queue checks run\n(same required checks\nagainst merge candidate)"]
    QUEUE_CHECKS --> QUEUE_DEC{Pass within\n60 min timeout?}

    QUEUE_DEC -->|Yes| SQUASH["Squash merge to main\n1 PR at a time"]
    SQUASH --> MERGED(["Merged\nPost-merge monitor starts"])

    QUEUE_DEC -->|"Timeout (> 60 min)"| QUEUE_REMOVE["Removed from queue\nAuthor notified"]
    QUEUE_DEC -->|"Checks fail"| QUEUE_REMOVE
    QUEUE_REMOVE --> AUTHOR_DEC{Author\naction?}
    AUTHOR_DEC -->|"Push fix commits"| PR_OPEN
    AUTHOR_DEC -->|"Stale > 30 days"| STALE_CLOSE(["Auto-closed by stale-management.yml"])

    QUEUE --> WAIT_SLOT["Wait if queue has\nother entries\n(min_entries_to_merge_wait_minutes=5)"]
    WAIT_SLOT --> BUILD

    style PR_OPEN fill:#e1f5ff
    style MERGED fill:#c8e6c9
    style QUEUE_REMOVE fill:#ffccbc
    style STALE_CLOSE fill:#ffccbc
```

### Timeout and retry boundaries

| Boundary | Value | Source |
|---|---|---|
| Queue check timeout | 60 min | `check_response_timeout_minutes: 60` |
| Max concurrent builds | 5 | `max_entries_to_build: 5` |
| Merge batch size | 1 | `max_entries_to_merge: 1` |
| Batch wait window | 5 min | `min_entries_to_merge_wait_minutes: 5` |
| Stale mark threshold | 30 days | `stale-management.yml` `STALE_DAYS` |
| Stale close threshold | +14 days | `stale-management.yml` `CLOSE_DAYS` |
| Required status check jobs | `validate-commit-messages`, `validate-unix`, `validate-windows` | `validate-basecoat.yml` |

---

## Assumptions

1. Retry attempt counting is operator-managed; no workflow tracks cross-run attempt counts internally. Operators should inspect the remediation issue comment history to determine retry depth before exhausting the budget.
2. `gate:needs-check-in` and `gate:no-tests` labels are applied by queue gate logic documented in `agents/basecoat-60-workflow-queue-rebalancer.agent.md`.
3. Stale exemptions apply: items labelled `pinned`, `security`, or `do-not-close` are skipped by `stale-management.yml`.
4. The merge queue is scoped to `refs/heads/main`; `release/*` branches are not yet enrolled (see `docs/operations/merge-queue-enforcement.md`).

## Intended operator usage

1. **Primary loop**: Use Diagram 1 to orient yourself when a delivery stalls — identify which phase the work is in, check the corresponding workflow run, and decide whether to retry, escalate, or close.
2. **Escalation loop**: Use Diagram 2 when a remediation issue appears. Confirm the attempt count, check `rollback_ref` availability in `agent-merge.yml`, and apply `gate:needs-check-in` to park the loop for human triage.
3. **Merge/queue loop**: Use Diagram 3 when PRs are sitting in the queue unexpectedly. Check queue check timeout (60 min), verify required checks are green, and confirm merge queue configuration has `max_entries_to_merge: 1` to avoid race conditions.
4. **Stale recovery**: If work was auto-closed, reopen the issue with updated context to reset the activity window and re-enter the triage phase.
