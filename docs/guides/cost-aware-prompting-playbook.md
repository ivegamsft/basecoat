# Cost-Aware Prompting Playbook for Advanced CLI Workflows

Use this playbook when running long, multi-phase CLI delivery loops where token
spend is driven more by context carryover than by output size.

Canonical model policy: `docs/reference/model-routing-defaults.md`. Premium
tier (Opus) is opt-in; named models below are examples, not pins.

## Quick Routing Matrix

| Work shape | Session move | Model default | Execution style |
|---|---|---|---|
| Mechanical cleanup (branch/worktree hygiene, scans, formatting) | Stay in session; `/compact` at phase boundary | Mini / flash class (example: `gpt-5.4-mini`) with omitted `reasoning_effort` | Interactive or delegated batch |
| Moderate reasoning (triage, planning, scoped reviews) | Stay in session if same objective; `/compact` on phase switch | Standard class (example: `claude-sonnet-5`) | Delegate scan work, keep decisions in main thread |
| Hard ambiguity (architecture, deep debugging, security tradeoffs) | Use a focused session if objective changes | Standard first; premium only with a written trigger | Time-boxed deep pass, then downshift |

## Phase-Boundary Rule: `/compact` vs `/new`

1. Use `/compact` when the objective is unchanged but the phase changes:
   triage -> implementation -> merge waiting -> closeout.
2. Use `/new` when objective or deliverable changes:
   cleanup -> RCA, implementation -> unrelated docs pack, repo A -> repo B.
3. Before either command, preserve a canonical handoff pointer:
   issue URL, active PR URL, branch, and one short done/next/blocked note.

## Fleet and Delegation Rule

Use delegation when the task is broad but mechanical. Keep the main thread
decision-only.

- Delegate: repository scans, issue sweeps, dependency checks, repetitive status loops.
- Keep in main thread: merge decisions, release gate approvals, risk acceptance.
- Sub-agents default to mini or standard. Do not pass the parent premium model into a scan.

Batch related work in one kickoff and monitor with `/tasks` rather than repeated
restarts of the same orchestration intent.

At each phase boundary, record model family and a one-line cost rollup when
usage is available. Warn if premium ran without a trigger; do not block.

## Durable Learnings Pattern

When a cycle finishes, capture one compact learning artifact so the next run does
not require prompt reconstruction.

Recommended capture shape:

```text
Cycle summary
- Scope: <issue/goal>
- Decisions: <2-4 bullets>
- Evidence: <PR/workflow links>
- Next trigger: <what starts next cycle>
- Stop condition met?: <yes/no + reason>
```

Store this where the team can reuse it (issue/PR comment, runbook section, or
canonical summary file path referenced by future sessions).

## Minimal Start Prompt Template

```text
Goal: <single objective>
References: <issue/PR/spec links>
Mode: <interactive|fleet>
Constraints: required checks, merge pacing, stop condition
Cost policy: compact at phase boundaries; new session on domain pivot
```

## Exit Checklist

- Objective completed or explicit stop condition reached.
- Required checks and evidence links captured.
- Branch/worktree cleanup status recorded.
- Next cycle can start from links, not transcript replay.
