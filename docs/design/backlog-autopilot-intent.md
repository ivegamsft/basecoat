# Design: Backlog Autopilot Intent (`autopilot:`)

## Summary

A continuous backlog-delivery intent that burns the issue backlog oldest to
newest in dependency-ordered waves. For each item it runs
design, debate, scope, dependency mapping, positive and negative tests,
implementation, commit/push/PR, merge-queue landing, and deploy to the final
destination. It paces itself to avoid merge conflicts and API throttling, and
continues unattended until stopped or blocked. It runs standalone
(single session) or as a fleet.

The intent is a thin orchestration layer. It owns sequencing, cadence, and
gates, and delegates every unit of work to assets that already exist. It
formalizes today's ad-hoc "Fleet Persistent Control-Loop Mode" into a
first-class, testable contract.

## Audit: Reuse-First Capability Map

| Required capability | Existing asset(s) | Coverage |
|---|---|---|
| Persistent bounded loop (cycles, retries, dry-run, stop conditions) | `ship-it-control-loop` agent/skill; Fleet Persistent Control-Loop Mode | Full |
| Approve-once issue to PR to release, merge policy, escalation | `delivery-autopilot` agent/skill; `scripts/delivery-autopilot/*.ps1` | Full |
| Oldest-first backlog selection, burn-down, spillover pressure | `backlog-burndown` skill; `issue-triage`; `fleet:` | Partial |
| Fleet fan-out and latest-main preflight | `parallel-session-coordinator`; `fleet:` | Full |
| Dependency-ordered batching | `wave:` intent; `dependency-blocker-monitor`; `dependency-lifecycle` | Partial |
| Design, scope, debate gates | `solution-architect`; `task-scope-validator`; `design-debate` format | Partial |
| Positive and negative tests | `strategy-to-automation`; `contract-testing`; `e2e-test-strategy` | Partial |
| Commit/push/PR and broken-build recovery | `merge-coordinator`; `broken-build-troubleshooter`; `self-healing-ci` | Full |
| Monitor blocks and broken builds | `dependency-blocker-monitor`; `automation-stuck-state-watchdog.yml`; `self-healing-ci` | Full |
| Deploy to final destination | `post-merge-release-chain.yml`; `publish-to-production.yml`; `ship-it-release-gate` | Full |
| Merge queues | `pr-auto-merge-executor.yml` (`merge_queue_posture`); `merge_group` triggers | Gap |
| Anti-throttle, steady pace, conflict-avoidance | control-loop serialized merges | Gap |

Roughly 70 percent of the required behavior already exists but is fragmented
across four agents, several skills, and three workflows. No single named intent
ties oldest-to-newest backlog burndown, dependency waves, design/debate/test
gates, merge-queue landing, and deploy into one unattended contract.

## Debate

Question: introduce a new intent, or extend `fleet:` / `wave:`?

### Option A: extend `fleet:`

- Pros: no new prefix; already fan-out oriented.
- Cons: `fleet:` is sprint-boundary scoped (closeout, plan, cleanup) and runs
  once. Overloading it with a continuous oldest-first delivery loop blurs its
  contract and breaks its eval coverage.

### Option B: extend `wave:`

- Pros: already dependency-ordered batch semantics.
- Cons: `wave:` is a single batch, not a continuing loop; it has no lifecycle or
  deploy semantics.

### Option C: new `autopilot:` intent that composes existing assets (selected)

- Pros: clean, self-descriptive boundary ("run the backlog unattended, wave
  after wave, until stopped or blocked"); reuses `delivery-autopilot`,
  `ship-it-control-loop`, `backlog-burndown`, `parallel-session-coordinator`,
  and the release chain; distinct eval surface; works standalone or as a fleet.
- Cons: one new prefix plus routing and eval entries; must avoid drift with
  `fleet:` and `wave:`.

### Decision

Create `autopilot:` as a thin orchestration intent that owns sequencing,
cadence, and gates, and delegates all work to existing assets.

## Design

### One-line contract

Burn the backlog oldest to newest in dependency-ordered waves. For each item run
design, debate, scope, dependency mapping, positive and negative tests,
implementation, PR, serialized landing, and deploy. Pace to avoid conflicts
and throttling. Continue until stopped or blocked.

### Per-wave phase gates

Each gate delegates to an existing asset. A failed gate blocks the wave, not the
whole loop.

1. Select — `backlog-burndown` plus `issue-triage`: pick the oldest N open,
   actionable issues; exclude blocked or needs-info.
2. Dependency-map to wave — `dependency-lifecycle` and
   `dependency-blocker-monitor`: topological sort; a wave is the set of items
   with no unmet in-wave dependency.
3. Design and debate — `solution-architect` plus the `design-debate` format:
   emit options and a decision for non-trivial items (plan-first gate already
   mandated by `basecoat-10-core-plan-first`).
4. Scope — `task-scope-validator`: bound the change; reject scope creep.
5. Tests (positive and negative) — `strategy-to-automation` with
   `contract-testing` or `e2e-test-strategy`: mandatory positive and negative
   cases before or with implementation.
6. Implement, commit, push, PR — worktree per item, conventional commits,
   required trailers, `Closes #<issue>`.
7. Land — serialized, conflict-free landing via
   `scripts/backlog-autopilot/merge-gate.ps1`, which keeps at most one autopilot
   PR in flight. When the target branch has a GitHub-native merge queue
   (`merge_group`), the PR lands through it. Because `pr-auto-merge-executor`
   blocks auto-merge under `required` posture, a branch without a native queue is
   a blocking policy gate: the lane is escalated (a human enables the queue or
   changes posture), not auto-merged. Enabling the queue is a branch-protection
   change the agent does not make (see Out of Scope).
8. Monitor — `self-healing-ci`, `broken-build-troubleshooter`, and
   `automation-stuck-state-watchdog`: on red, auto-diagnose and retry within
   `max_retries`, else escalate and mark blocked.
9. Deploy to final destination — `post-merge-release-chain` to
   `publish-to-production` (external mirror), gated by `ship-it-release-gate`.
10. Cycle report — reuse the `ship-it-control-loop` report schema; advance to
    the next wave.

### Control knobs

From `ship-it-control-loop`: `max_cycles`, `max_retries`, `dry_run`,
`stop_conditions`. New: `wave_size`, `pace` (minimum interval between merges),
`concurrency` (1 for standalone; N for fleet).

### Anti-throttle and no-conflict design

- Serialized merge queue: one PR lands at a time, so merge conflicts are avoided
  by construction.
- Pacing budget: minimum seconds between merges and between API bursts;
  exponential backoff on `403` and `429` and secondary-rate-limit responses.
- Rebase-before-push each lane on `origin/main` (already mandated by Worktree
  Sync Enforcement) so queue entries do not stale-fail.
- Concurrency cap at or below CI runner capacity.

### Stop conditions

Backlog empty, blocking dependency or policy gate, `max_cycles` reached, manual
stop, or repeated deploy-gate failure.

### Standalone versus fleet

Same contract. `concurrency=1` runs it in one session; `concurrency=N` starts
via `parallel-session-coordinator` with the latest-main preflight.

## Gaps Closed by This Change

1. `autopilot:` prefix added to `basecoat-10-core-intent-routing.instructions.md`
   and its alias, with an execution contract.
2. `backlog-autopilot` agent (thin conductor) plus routing eval companion.
3. Wave-builder script: oldest-first plus dependency topological sort produces
   the wave list.
4. Merge-queue enablement: autopilot config declares `merge_queue_posture:
   required` and `serialize_merges: true`, consumed by `merge-gate.ps1` to keep
   one PR in flight and to surface a policy block (escalate, do not auto-merge)
   when the target branch lacks a native merge queue.
5. Pacing and anti-throttle helper: cadence and exponential backoff consumed by
   the loop.
6. Mandatory positive-and-negative test gate wired into the agent contract via
   `strategy-to-automation`.
7. Routing and eval sync: `wave:`, `fleet:`, and `autopilot:` cross-linked, with
   eval coverage so the intents do not drift.

## Out of Scope

- Changing global repository merge policy for non-autopilot lanes.
- Mutating live branch-protection settings from the agent.
- Replacing sprint planning or retrospective analysis.
