# Backlog Autopilot — Workflow Detail

Supporting detail for [`agents/basecoat-60-workflow-backlog-autopilot.agent.md`](../basecoat-60-workflow-backlog-autopilot.agent.md).

## Configuration

Read `scripts/backlog-autopilot/autopilot.config.json` for the merge posture and
pacing defaults. Autopilot lanes run under `merge_queue_posture: required` and
`serialize_merges: true`, so at most one PR lands at a time through the
GitHub-native merge queue. Because `pr-auto-merge-executor` blocks auto-merge
under `required` posture, a target branch **without** a native merge queue is a
blocking policy gate: the lane cannot land unattended and must be escalated
(enable the queue or adjust posture) rather than auto-merged. Use
`scripts/backlog-autopilot/merge-gate.ps1` to obtain the arm/hold and
policy-block decision; the agent never mutates branch-protection settings itself.

## Full Per-Cycle Workflow

Run one wave per cycle. Each cycle:

1. Preflight. Standalone starts here; fleet starts from
   `@parallel-session-coordinator` and confirms latest-main sync before any
   write-capable lane starts.
2. Select. Use `backlog-burndown` and `@issue-triage` to pick the oldest
   `wave_size` open, actionable issues. Exclude blocked and needs-info.
3. Build wave. Run `scripts/backlog-autopilot/build-waves.ps1` to produce the
   oldest-first, dependency-topological-sorted wave.
4. Per item, run phase gates in order (a failed gate blocks the item, not the
   loop):
   - Design and debate via `@solution-architect` and the `design-debate` format.
   - Scope via `@task-scope-validator`.
   - Positive and negative tests via `@strategy-to-automation` (mandatory: both
     a positive and a negative case before or with implementation).
   - Implement in a worktree per item; conventional commits; required trailers;
     `Closes #<issue>`.
5. Land. Open the PR, then consult
   `scripts/backlog-autopilot/merge-gate.ps1`. When the target branch has a
   native merge queue, land through it, serialized to one PR in flight. If
   merge-gate reports a policy block (required posture, no native queue), do not
   attempt auto-merge — the executor forbids it — mark the item blocked and
   escalate. Never merge when required checks are not green.
6. Pace. Call `scripts/backlog-autopilot/pace-gate.ps1 -Mode interval` between
   merges and `-Mode apiburst` around batches of gh/API calls to hold a
   throttle-safe cadence, with `-Mode backoff` for exponential backoff on `403`,
   `429`, and secondary-rate-limit responses.
7. Monitor. On red or stall, delegate to `@self-healing-ci`,
   `@broken-build-troubleshooter`, and `automation-stuck-state-watchdog`; retry
   within `max_retries`, else escalate and mark the item blocked.
8. Deploy. Advance merged work to the final destination via
   `post-merge-release-chain` and `publish-to-production`, gated by the ship-it
   release gate.
9. Report. Emit a per-cycle checkpoint (`ship-it-control-loop` schema) and
   advance to the next wave.
