# Kept Pattern Runbook: Single Kickoff Plus `/tasks` Monitoring

## Intent

Lower orchestration overhead by issuing one structured kickoff and steering via
status monitoring plus minimal delta prompts.

## Prerequisites

- Objective, constraints, and success conditions are clear.
- A suitable specialist skill or agent is known.
- Merge pacing and required-check rules are defined for the run.

## Default Procedure

1. Start the workflow once with complete initial context and success criteria.
2. Monitor progress via `/tasks` instead of restarting orchestration loops.
3. Send short delta instructions only when scope changes or blockers appear.
4. Keep merge operations serialized and gated on required checks.

## Decision Points

| Condition | Action |
|---|---|
| Work is progressing in scope | Continue monitoring with `/tasks` |
| New blocker or dependency emerges | Send one focused delta instruction |
| Work objective changes materially | Start a new governed session |

## Rollback

If the active run drifts or stalls, stop issuing ad hoc restarts and open one
fresh kickoff with updated scope, then resume monitoring from that single control
point.

## Evidence to Capture

- Number of orchestration restarts avoided.
- Main-session tool-call count per phase.
- Required-check pass and merge-latency trend for governed PRs.
