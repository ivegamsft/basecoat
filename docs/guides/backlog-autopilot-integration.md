# Backlog Autopilot Integration

The `autopilot:` intent burns the issue backlog oldest to newest in
dependency-ordered waves and runs unattended until stopped or blocked. It is a
thin orchestration layer over existing BaseCoat assets. See the design and
debate in `docs/design/backlog-autopilot-intent.md`.

## Components

| Component | Path | Purpose |
|---|---|---|
| Agent | `agents/basecoat-60-workflow-backlog-autopilot.agent.md` | Conductor for the `autopilot:` loop |
| Routing eval | `agents/basecoat-60-workflow-backlog-autopilot.agent.eval.yaml` | Trigger-activation coverage |
| Config | `scripts/backlog-autopilot/autopilot.config.json` | Merge-queue posture, pacing, selection defaults |
| Wave builder | `scripts/backlog-autopilot/build-waves.ps1` | Oldest-first, dependency-topological wave list |
| Pace gate | `scripts/backlog-autopilot/pace-gate.ps1` | Merge-interval and exponential backoff decisions |
| Routing | `instructions/basecoat-10-core-intent-routing.instructions.md` | `autopilot:` prefix contract |

## Invocation

Standalone:

```text
autopilot: burn the backlog oldest to newest, wave_size=5, concurrency=1
```

Fleet:

```text
autopilot: burn the backlog as a fleet, wave_size=5, concurrency=4
```

Fleet mode starts from `@parallel-session-coordinator` with a latest-main
preflight before any write-capable lane starts.

## Building a wave

```powershell
pwsh scripts/backlog-autopilot/build-waves.ps1 -Repo ivegamsft/basecoat -WaveSize 5
```

Pass `-InputPath issues.json` to run against a fixed issue list (offline or test
mode). The output lists ordered waves and any items blocked by unresolved
dependencies or cycles.

## Pacing

```powershell
# Wait time before the next merge (steady, conflict-safe pace)
pwsh scripts/backlog-autopilot/pace-gate.ps1 -Mode interval -LastMergeUtc "2026-07-27T10:00:00Z"

# Exponential backoff after a throttled response
pwsh scripts/backlog-autopilot/pace-gate.ps1 -Mode backoff -Attempt 2 -StatusCode 429
```

## Landing and deploy

Autopilot lanes run under `merge_queue_posture: required`, so
`pr-auto-merge-executor` defers to the GitHub-native merge queue (`merge_group`)
and merges stay serialized and conflict-free. Landed work advances to the final
destination via `post-merge-release-chain` and `publish-to-production`, gated by
the ship-it release gate.

## Guardrails

- Never merge when required checks are not green.
- Never bypass documented human-approval boundaries.
- Always dry-run a cycle before first live execution on a new lane.
- Land only through the merge queue; never force-merge to avoid conflicts.
