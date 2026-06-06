---
description: "Session hygiene, fleet management, and token cost optimization patterns"
applyTo: "**/*"
---

# Cost Optimization & Session Management

## Session Hygiene

Baseline CLI cost (2.08B tokens/mo) reduced through five behavioral patterns:

### 1. Use /compact mid-session

Invoke `/compact` to summarize and clear history when:
- Session exceeds 500 minutes
- Input token events exceed 500 in one phase
- Context feels bloated after many tool calls

Expected savings: 15-20% per session compaction.

### 2. Use /new between work waves

Start fresh context between independent work blocks:
- After completing a feature → `/new`
- After major context shift → `/new`
- Between separate issue sprints → `/new`

### 3. Direct skill targeting (not /basecoat router)

Call specialized skills directly; skip router overhead:

| Intent | Call This |
|---|---|
| Triage issues | `/issue-triage` |
| Plan sprint | `/sprint-planner` |
| Fix build failure | `/build-failure-triage` |
| Clean branches | `/branch-hygiene-sweeper` |
| Review code | `/code-review` |

See `.github/instructions/routing-decision-tree.md` for complete mapping.

Expected savings: 46M tokens/mo (~500k tokens per direct call).

### 4. Preflight checks before unattended runs

Before long/unattended sessions:

```
/env                   (verify repo/org)
/user                  (verify ibuyspy account)
/usage                 (check token budget)
```

Prevents auth-context errors and wasted cycles.

### 5. Model downshift for routine work

Use cheaper models for triage/CI/audit:
- `gpt-5.4-mini` for issue triage, branch cleanup, config audits
- `claude-haiku-4.5` for log analysis, dependency checks
- Reserve `claude-opus` for architecture, security, complex decisions

Expected savings: 20% cost reduction on routine agents.

## Fleet Patterns

### Single Kickoff + /tasks Monitoring

Instead of repeated `/basecoat` calls (96/mo), use:

1. Start once: `/basecoat [initial directive]`
2. Monitor progress: `/tasks`
3. Steer with deltas: `Continue from issue #695; merge PRs after checks`

Reduces per-restart overhead by ~500k tokens.

### Delta Prompts

Avoid repeating boilerplate; use compact deltas:

**Before** (2KB):
```
continue until blocked, i am stepping away, merge pacing text, skip replanning...
```

**After** (200 bytes):
```
Continue from issue #695 state; only merge PRs after required checks; skip replanning.
```

### Retire Stale Schedules

Scheduled prompts (`/every`) that run >100 times/month cost ~150M tokens/mo.
After watchdog stops being actionable, stop it: `/every stop <schedule-id>`.

## Token Budget Monitoring

Track in each session:
- `/compact` calls (target: ≥1 per 500 min)
- `/basecoat` calls (target: <4 per phase)
- Model selections (target: 80% gpt-5.4-mini for routine, 20% opus for complex)
- Input tokens (baseline: 2.08B/mo; target: 1.2B/mo after optimizations)

Expected Phase 1 + Phase 3 combined: 42% reduction (~150M tokens/mo savings).
