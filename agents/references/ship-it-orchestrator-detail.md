# Ship-it Orchestrator — Control-Loop Contract

Supporting detail for [`agents/basecoat-60-workflow-ship-it-orchestrator.agent.md`](../basecoat-60-workflow-ship-it-orchestrator.agent.md).

## Lane-closeout behavior

Invoke `lane-closeout` for every in-scope branch/worktree. For upper layers in a stacked PR chain, capture WIP
and use the supported `HANDED_OFF` or `PARKED` outcome without terminal merge/rebase; use full closeout for
terminal integration and finalization lanes. Merge bottom-up and refresh the stack only when a lower layer
changes. Let the skill classify `MERGED`, `HANDED_OFF`, `ABANDONED`, or `PARKED`, and prune only authorized
terminal lanes after all gates pass.

## Control-Loop Contract

Run delivery as a bounded loop, not as an unbounded restart pattern.

### Required loop state per cycle

1. `cycle_id`: monotonic counter for this goal.
2. `phase`: one of `intake`, `plan`, `implement`, `validate`, `release`, `closeout`.
3. `objective`: single active objective for the cycle.
4. `stop_condition`: explicit done condition or block condition.
5. `max_cycles`: safety cap to prevent infinite orchestration.
6. `retry_count_by_subtask`: per-subtask retry counter.

## Cycle summary output (emit every cycle)

1. Current phase and objective
2. Completed actions in this cycle
3. Gate/evidence status with links
4. Blockers and owner
5. Next action or stop reason
6. Status board snapshot: active tasks, open PRs in scope, required checks state

## Retry policy

1. Retry failed subtasks only when failures are classified as transient.
2. Cap retries per subtask at `max_retries`.
3. Escalate to blocker/RCA path after retry exhaustion.
4. In `dry_run` mode, emit planned retries and escalation points without side effects.

## Stop conditions

Stop the loop when any condition is met:

1. Required gates pass and release/closeout evidence is complete.
2. A blocking dependency cannot be resolved inside current scope.
3. `max_cycles` is reached without converging to a releasable state.
4. All in-scope PRs are merged/closed with required checks green.
5. Manual stop is issued by operator.
