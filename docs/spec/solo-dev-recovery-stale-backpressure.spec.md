# Technical Specification: Solo-Dev Recovery Stale-Run Backpressure

## Status and Authority

Proposal for the residual of
[source #3590](https://github.com/IBuySpy-Shared/basecoat/issues/3590).
Merging this document does not authorize runtime changes, approve the source
issue, or complete its acceptance criteria. Owner approval of this spec is
required before implementation. It also scopes the reconciliation part of
[#3645](https://github.com/IBuySpy-Shared/basecoat/issues/3645) and is the
prerequisite recorded for #3669, #3670, #3671 and #3672.

## Context

[PR #3619](https://github.com/IBuySpy-Shared/basecoat/pull/3619) (merge commit
`7e20edb4d60bdda499a19ecd159085a4352f49db`) added the trusted scheduled
`Recover missed current-head eligibility` job in
`.github/workflows/auto-approve-cloud-agent-workflows.yml` and its distributed
copy. It routes solo-dev by the selected profile, needs no human review, and
leaves the executor as the sole authorization authority. The contract is in
[delivery-recovery-spec.md](../reference/delivery-recovery-spec.md).
[PR #3684](https://github.com/IBuySpy-Shared/basecoat/pull/3684) later closed
issue #3604, so executor queue admission now triggers merge-group checks.

### Residual Evidence (baseline `69beb41d`, 2026-10-12 UTC)

- Before dispatching, the recovery step defers if `listWorkflowRuns` for
  `pr-auto-merge-executor.yml` returns `total_count > 0` for any of `queued`,
  `in_progress`, `waiting`, `pending` or `requested`.
- Four executor runs (`37655520651`, `37642391086`, `37642380421`,
  `37642379767`, all `workflow_run`, created 2026-10-07 15:08 to 16:55 UTC) are
  still reported `queued`. Each run's jobs list returns `total_count: 0`.
  According to #3645, cancellation returns contradictory 409 responses.
- All 21 scheduled recovery runs since #3619 deployed (from `37692631841`
  through `38212370945`) logged `Recovery deferred: executor has queued work.`
  None dispatched an evaluation. During the same sample, `in_progress`,
  `waiting`, `pending` and `requested` counts were 0.
- Event-driven evaluation and queue admission work. For example, PR #3815
  merged through the native queue on 2026-10-12. Manual recoveries on #3598,
  #3599, #3632, #3652, #3657 and #3664 merged after exact merge-group checks.
- The recovery summary still says #3604 is unfixed, which is now stale.

Result: the first acceptance criterion of #3590 is not met. A green, ready PR
whose completion events were missed is never re-evaluated by scheduled recovery.
The phantom runs permanently hold the global backpressure gate closed.

## Scope

1. Classify executor runs that GitHub reports as `queued` into live and
   stale-phantom runs. Only live runs block recovery. This is a bounded
   fail-open of a load-shedding heuristic, not of authorization; see
   "Accepted Fail-Open Boundary" below.
2. Report the classification, dispatch counts and the post-#3684 queue posture
   in the recovery run summary.
3. Prove the first #3590 acceptance criterion live on hosted runs.

## Out of Scope

- Cancelling, deleting or re-running phantom runs. That is still #3645's
  platform question.
- Changes to the executor, authorization, reviews, policy packs, tokens, queue
  credentials, rulesets or merge-queue settings.
- Ordered admission (#3671), protected-boundary enforcement (#3672), completion
  readiness (#3669) and stack handoff (#3670).
- Changes to the bounds from #3619: 100-PR page, 20 inspected, 5 dispatched,
  30-minute cooldown, 50 runs per head and the 200-status budget.

## Architecture Overview

Only the backpressure prologue of `Dispatch current eligibility evaluations`
changes. All later steps stay the same: candidate discovery,
`recoveryEvidence` fingerprints, live reread and `createWorkflowDispatch`.

```text
for status in [in_progress, waiting, pending, requested]:
    total_count > 0                        -> defer("<status>")
queued = listWorkflowRuns(status=queued, per_page=20)
queued.total_count > 20                    -> defer("queued-overflow")
for run in queued.workflow_runs:
    age < STALE_QUEUED_HOURS               -> defer("queued")
    run.updated_at != run.created_at       -> defer("queued")
    listJobsForWorkflowRun(run.id) fails   -> defer("queued-unverified")
    jobs.total_count > 0                   -> defer("queued")
    otherwise                              -> stalePhantom.push(run.id)
stalePhantom.length > MAX_TOLERATED_PHANTOMS -> defer("phantom-overflow")
proceed with unchanged discovery; summary lists stalePhantom
```

## Data Model and Storage Changes

None. No statuses, labels, comments, artifacts or variables are added. The
classification exists only for the current run and its job summary.

## API and Interface Contracts

| Item | Contract |
| --- | --- |
| `STALE_QUEUED_HOURS` | Constant `24`. Executor jobs time out after at most 20 minutes once started, and the observed phantom runs are more than 100 hours old. 24 hours leaves wide margin for runner, concurrency or platform delays before a run is ignored. |
| `MAX_TOLERATED_PHANTOMS` | Constant `8`. Twice today's four phantom runs. More stale-phantom runs indicates a platform incident, so recovery defers. |
| Stale-phantom definition | `status == queued`, `created_at` older than 24 hours, `updated_at == created_at` (no state transition since creation), and `GET /actions/runs/{id}/jobs` returns `total_count == 0`. All four are required. |
| Dominance | Classification is all-or-nothing per tick: any single live run in the response defers the whole tick, regardless of how many stale-phantom runs are also present. |
| Read bound | One `queued` list page (`per_page: 20`), at most 20 jobs-list reads, and four other status probes. That is at most 25 extra reads per tick. |
| Overflow | Defer if more than 20 runs are `queued`. Never page further. |
| Permissions | Unchanged: `actions: write` (already present for dispatch) covers run and job reads. No new scopes. |
| Workflow inputs and outputs | Unchanged. Executor dispatch inputs stay `pr_number` and `recovery_fingerprint`. |
| Distribution | Root and `.github/base-coat/` workflow copies change identically. |

## Security and Privacy Considerations

- Classification affects only whether recovery may request a fresh
  evaluation. Dispatch never grants eligibility. The executor still enforces
  fresh policy, spec, approval, checks, holds and snapshot validation.
- Fail closed on uncertainty. Any read error, overflow, recent or updated
  `queued` run, or `queued` run with jobs keeps today's deferral.
- No untrusted input is involved. Run IDs, timestamps and job counts come from
  the GitHub API for the trusted default-branch workflow.
- No credential, token-owner or permission changes. Phantom runs are never
  mutated.

### Accepted Fail-Open Boundary

The stale-phantom rule cannot prove that GitHub will never start a run. If a
run that matches all four conditions later starts, recovery may already have
dispatched up to five evaluations for other PRs during the same tick. The
executor's concurrency key serializes only per PR, so those evaluations can
run concurrently with the late run. This is the only fail-open behavior in the
proposal. It is bounded by the five-dispatch cap, the 30-minute watermark
cooldown and the 50-runs-per-head cap. It affects executor load only, never
eligibility or admission decisions, which the executor re-derives from fresh
evidence. Owner approval of this spec explicitly accepts this boundary. The
alternative, waiting for a supported cancellation path in #3645, leaves
scheduled recovery disabled indefinitely.

## Reliability and Failure Modes

| Failure | Behavior |
| --- | --- |
| Real queued executor run younger than 24 hours | Defer (unchanged) |
| Queued run older than 24 hours that has jobs or a state transition | Defer |
| Phantom run later starts | Accepted fail-open boundary for at most one tick; from the next tick it has jobs or another status, so recovery defers |
| More than 8 stale-phantom runs | Defer with `phantom-overflow` |
| Jobs API 4xx/5xx or rate limit | Defer with `queued-unverified` and record it in the summary |
| More than 20 queued runs | Defer with `queued-overflow` |
| Race with event-driven evaluation | Unchanged: the executor's serialized per-PR mailbox and the 30-minute watermark cooldown |
| Phantom set grows without bound | Bounded by overflow deferral, which is observable in the summary |

## Performance and Capacity Considerations

There are at most 25 extra REST reads (one list, four status probes, 20 jobs reads) per scheduled tick. Today's observed
schedule is about four ticks per day, and the cron is `*/15`. Dispatch bounds
from #3619 stay in force.

## Implementation Plan

| Order | Files | Change |
| --- | --- | --- |
| 1 | `.github/workflows/auto-approve-cloud-agent-workflows.yml`, `.github/base-coat/workflows/auto-approve-cloud-agent-workflows.yml` | Replace the `queued` probe with the bounded classification. Add `defer reason` and `stale-phantom run IDs` to the summary. Replace the stale #3604 sentence with: queue admission and merge-group checks are owned by the executor, and dispatch is not admission. |
| 2 | `tests/delivery-recovery-tests.cjs` | Add the scenarios in Testing Strategy against both workflow copies. |
| 3 | `docs/reference/delivery-recovery-spec.md` | Document stale-phantom backpressure and remove the outdated #3604 limitation. |

The expected size is 4 files and about 120 changed lines, as one individual
delivery unit.

## Testing Strategy

Mocked REST tests in `tests/delivery-recovery-tests.cjs`, run against both
installed copies:

- `phantom-queued`: one `queued` run that is 2 days old, never updated, with
  0 jobs, so recovery dispatches the zero-review solo-dev PR and the summary
  lists the run.
- `recent-queued`: a `queued` run that is 5 minutes old with 0 jobs, so
  recovery defers.
- `queued-with-jobs`: a `queued` run that is 2 days old with 1 job, so
  recovery defers.
- `queued-updated`: a `queued` run that is 2 days old with 0 jobs but
  `updated_at` later than `created_at`, so recovery defers.
- `mixed-queued`: one response containing two stale phantoms plus one recent
  zero-job run, and separately two stale phantoms plus one old job-bearing run.
  Both defer, independent of list order, proving any live run dominates.
- `phantom-overflow`: nine stale phantoms, so recovery defers.
- `jobs-read-error`: the jobs API throws, so recovery defers with
  `queued-unverified`.
- `queued-overflow`: `total_count` is 21, so recovery defers and makes no
  jobs reads.
- `phantom-plus-in-progress`: recovery defers on `in_progress`.
- Existing draft, held, fork, stale-head, cooldown, bound and dispatch-error
  scenarios stay green unchanged.

Commands: `node --test tests\delivery-recovery-tests.cjs`,
`pwsh -NoProfile tests\auto-approve-cloud-agent-workflows-tests.ps1`,
`pwsh -NoProfile tests\pr-auto-merge-executor-tests.ps1`, actionlint on both
workflow copies, and `pwsh -NoProfile scripts\validate-basecoat.ps1`.

Live acceptance, which source tests cannot prove:

1. After merge, the first scheduled or manual recovery run logs the four
   phantom IDs as stale and does not log `Recovery deferred`.
2. A green, ready solo-dev PR with no human review and no current eligibility
   watermark receives a `recovery_fingerprint` executor dispatch. The executor
   then records current-head eligibility, and the PR either enters the native
   queue or is visibly blocked by the executor for a stated reason.
3. Draft, `delivery-hold`, fork and changed-head PRs present during that run
   are not dispatched.

## Rollout, Migration, and Rollback Plan

- Deliver through the native merge queue as one PR. There is no migration.
- Consumers receive the distributed copy through normal BaseCoat updates.
- Rollback: revert the PR. Recovery returns to deferring on any `queued` run,
  which is today's safe but non-recovering behavior.

## Observability and Operational Readiness

The job summary for every tick contains:

- the defer reason, or `none`;
- the count and IDs of stale-phantom runs;
- the count of inspected candidates;
- the count of dispatched evaluation requests;
- a statement that dispatch is not admission.

Operators can verify acceptance with
`gh run list -w auto-approve-cloud-agent-workflows.yml -e schedule` and the
executor `workflow_dispatch` runs carrying `recovery_fingerprint`. A sustained
`queued-overflow` or growing phantom set is the escalation signal for #3645.

## Risks and Mitigations

| Risk | Mitigation | Validation |
| --- | --- | --- |
| A genuinely pending run is misclassified | It must be 24 hours old, never updated and have 0 jobs; any live run dominates; residual exposure is the accepted, bounded fail-open boundary. | `recent-queued`, `queued-with-jobs`, `queued-updated`, `mixed-queued` tests |
| Recovery dispatch storms after unblocking | Unchanged 5-dispatch, 30-minute cooldown, 50-runs-per-head and status budgets | Existing `bounded`, `finite-cap` and `status-budget` tests |
| Readers treat recovery as delivery | The summary and spec keep dispatch, eligibility and admission distinct | Live acceptance step 2 |
| GitHub later clears or ages out phantom runs | Classification is then a no-op | None needed |

## Open Questions

- Should `STALE_QUEUED_HOURS` and `MAX_TOLERATED_PHANTOMS` be policy-pack
  values? This spec proposes constants so that policy packs and their digests
  stay unchanged.

## References

- [#3590](https://github.com/IBuySpy-Shared/basecoat/issues/3590),
  [#3645](https://github.com/IBuySpy-Shared/basecoat/issues/3645),
  [#3604](https://github.com/IBuySpy-Shared/basecoat/issues/3604)
- [PR #3619](https://github.com/IBuySpy-Shared/basecoat/pull/3619),
  [PR #3684](https://github.com/IBuySpy-Shared/basecoat/pull/3684)
- [Delivery recovery spec](../reference/delivery-recovery-spec.md)
- [PRD and spec guidance](../guides/prd-and-spec-guidance.md)
