---
description: "Session hygiene, fleet management, and token cost optimization patterns"
applyTo: "**/*"
---

# Cost Optimization & Session Management

## Session Hygiene

Baseline CLI cost (2.08B tokens/mo) reduced through five behavioral patterns:

### 1. Compact at phase transitions (not just time)

Invoke `/compact` when switching between semantic phases:
- **Triage → Implementation**: Backlog context is useless in code-change phase; drop it.
- **Implementation → Merge-waiting**: Code diff context is useless in CI-watch phase; drop it.
- **Merge-waiting → Next phase**: CI logs and merge status are transient; drop them.

Measured savings: reduces event count by 60–70% and tokens by 35–50% per compaction.
**Best-measured baseline**: 9.1M tokens, 101 events (207x ratio). Recent expensive runs had 68–84M tokens, 594–684 events (285x–434x ratio). Compaction at phase boundaries is the biggest win.

### 2. Reuse sprint templates instead of re-planning

Measured problem: 5 separate "Plan Next Sprint for Basecoat" sessions, averaging 39.5M tokens each (ratio 293x–498x).

**Solution**: Create a persistent sprint template (pinned issue or structured document) instead of re-planning from scratch each time.
- Use `/sprint-planner` agent with a reference to the template issue (e.g., "#1400: Sprint 31 Template")
- Agent loads backlog delta and sprints off that, not from scratch
- Eliminates repeated setup context

Expected savings: 150M+ tokens/month (5 sessions × 39.5M tokens).

### 3. Avoid pasting instruction dumps; use file references

Measured problem: Recent sessions had user messages with 170k, 149k, 141k character pasted instruction/skill/config blocks.

**Cost**: A 170k character paste inflates every subsequent turn's context if the session stays live. That's re-sent on every agent call, every turn, until compaction.

**Solution**: Use file references only. Let agents load their own docs.

**Instead of:**
```
[Paste 170k character SKILL.md or instruction file into chat]
```

**Do:**
```
See: /skills/station-bottleneck-analyzer/SKILL.md (agent will load via `view`)
See: /.github/instructions/testing-validation.instructions.md (agent will load)
```

Expected savings: ~300x tokens per pasted block (170k chars × context reuse cost over 50+ turns = prevented 8.5M tokens).

### 4. Delegate scan/research work; keep main session decision-only

Measured problem: Long backlog runs had 70–90 report_intent calls with heavy shell/tool back-and-forth in main session.

**Cost**: Each tool call, each report_intent, each result read in main session adds turn overhead. Over a 594-event session (68M tokens), orchestration dominates cost.

**Solution**: Batch related actions; delegate research and triage to background agents or `/delegate`.

**Main session responsibilities**:
- Decisions (merge? release? deploy?)
- High-level orchestration (kick off tasks, monitor `/tasks`)

**Delegated responsibilities** (to background agents):
- PR triage and review (use `/delegate` or background `/code-review`)
- File scanning and pattern matching (use background `/explore` agent)
- Dependency audits and CI analysis (use background `/build-failure-triage`)

Expected savings: Reduce main-session event count by 40–60%; cut orchestration overhead by 35–50%.

### 5. Model choice is secondary; context reduction is primary

Measured data from last 30 days: 42.4% gpt-5.3-codex, 24% gpt-5.4-mini, 18.2% Haiku, 14.4% Sonnet/Opus.

**Observation**: Most spend is already on cheaper models. Further model downshift yields only ~5–10% savings.

**Real win**: Sending less context to any model. Context reduction saves 35–50% per session (compaction + delegation + template reuse).

**Guidelines**:
- Use cheaper models (gpt-5.4-mini, Haiku) for known-simple tasks (triage, log analysis, config audits)
- Reserve Opus/Sonnet for architecture decisions, complex refactors, security reviews
- But don't obsess over model choice if the session is carrying 600+ events; compact first.

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

## Cost Observability & Auto-Compaction (In Development)

Issue #1363 is tracking implementation of real-time cost monitoring:

**Planned features**:
- `/token-status` command: Show tokens sent, event count, ratio, time, budget remaining
- Auto-compact trigger: Automatic `/compact` when crossing thresholds (e.g., 400 events, 50M tokens)
- Cost warnings: Log alerts when entering expensive zone (300x+ ratio, 594+ events)

**Expected impact**: Agents can self-correct mid-session without waiting for post-hoc feedback, shaving 10–15% from expensive sessions.

## Token Budget Monitoring

**Backlog session baseline**: 9.1M tokens, 101 events, 207x ratio (the target for efficiency).

**Expensive runs (antipattern)**: 68–84M tokens, 594–684 events, 285x–434x ratio.

Track in each session:
- **Events per session** (target: <150 per phase; expense threshold: >400 in a single session)
- **Compact calls** (target: ≥1 at each phase boundary; e.g., triage→impl, impl→merge)
- **Main-session tool calls** (target: <30 per phase; expense: >70 indicates heavy orchestration)
- **Pasted message size** (target: <10KB per user message; expense: >100KB is a red flag)
- **Re-plan occurrences** (target: 1 per sprint; expense: >1 per sprint means template reuse failed)

**Cost breakdown**:
- 50% of expense from re-sending context across 594 events in a single session
- 30% from repeated sprint re-planning (5 sessions × 39.5M each)
- 15% from pasted instruction dumps (170k+ characters re-sent per turn)
- 5% from heavy orchestration in main session (70–90 report_intent calls)

**Expected total savings from all 5 changes**: 35–50% reduction per backlog session (from 68–84M baseline to 35–45M target).
