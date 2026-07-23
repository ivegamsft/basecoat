# Phase-Boundary Session Hygiene Checklist

Use this checklist during long fleet or ship-it runs to decide whether to keep
the current session (`/compact`) or pivot to a fresh one (`/new`).

## Decision Rule

1. Use `/compact` when the objective is unchanged and only the phase changes.
2. Use `/new` when objective, domain, or deliverable changes.
3. Before either command, save a short handoff pointer:
   issue/PR URL, active branch, done/next/blocked note.

## Phase Pivot Table

| Transition | Preferred command | Why |
|---|---|---|
| Cleanup -> implementation on same issue | `/compact` | Keep issue context, drop cleanup noise |
| Implementation -> merge waiting | `/compact` | Keep acceptance criteria, drop code-edit detail |
| Merge waiting -> closeout on same issue | `/compact` | Keep release evidence, drop CI log churn |
| Cleanup -> RCA on unexpected failure | `/new` | RCA needs failure-focused context, not cleanup transcript |
| Implementation -> docs pack for unrelated feature | `/new` | New deliverable and audience |
| RCA -> follow-up implementation fix | `/new` | Switch from analysis to change-execution context |
| Any phase -> different repository | `/new` | Cross-repo context is not reusable |

## Fleet Loop Checkpoints

At each phase boundary:

1. Capture current `/tasks` snapshot.
2. Record PR/check status for in-scope work.
3. Confirm stop condition status (`continue|complete|blocked|max_cycles|manual_stop`).
4. Apply the decision rule (`/compact` vs `/new`) before continuing.

## Anti-Patterns

1. Repeating full orchestration prompts without carrying bounded loop state.
2. Using `/new` for minor phase changes in the same objective.
3. Keeping stale logs from cleanup or RCA when switching to unrelated docs work.
