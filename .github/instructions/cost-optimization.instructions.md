---
description: "Session hygiene, fleet management, and token cost optimization patterns"
applyTo: "agents/**/*,skills/**/*"
---

# Cost Optimization & Session Management

## Session Hygiene

Baseline CLI cost (2.08B tokens/mo) reduced through five behavioral patterns:

### Sprint 35 execution plan (issues #1420-#1424)

Execute these in order to reduce input-token bloat first, then optimize routing:

| Order | Issue | Focus | Output |
|---|---|---|---|
| 1 | #1420 | Phase-boundary compaction policy | Updated workflow/instruction guidance with explicit compact gates |
| 2 | #1421 | Large-payload carry-over elimination | File-reference-only policy plus `/new` or `/compact` pivot rules |
| 3 | #1422 | Main-thread orchestration reduction | Batching/delegation defaults with decision-only main-thread pattern |
| 4 | #1423 | Model-routing policy | Routine-loop model defaults with temporary upshift guidance |
| 5 | #1424 | Attachment context compression | Canonical summary artifact workflow/template |

### Operator checklist for every long CLI run

1. Start with short context and file references only.
2. At each phase switch (triage -> implementation -> merge waiting), run `/compact`.
3. If switching to a new domain (for example: sprint planning -> release operations), run `/new` and reload only relevant references.
4. Keep main-thread messages decision-focused; delegate scan/research work.
5. For attachment-heavy tasks, create one canonical summary artifact and reference it by path/link.
6. Choose Ask mode by default for focused answers; use Agent mode when execution spans multiple files, long-running commands, or broad research.
7. Keep output tokens lean by default: concise responses, small diffs, and escalation to deeper explanations only when needed.
8. Normalize rich files (PPTX, PDF, DOCX, XLSX) into one markdown summary artifact before reuse across turns.

Cross-reference surfaces:

- `docs/guides/token-optimization.md` (operator quick-start + normalization workflow)
- `.github/instructions/workflow-conventions.instructions.md` (session transition and mode defaults)
- `docs/reference/scoped-instructions.md` (scope design that prevents token-heavy universal activation)

### 1. Compact at phase transitions (not just time)

Invoke `/compact` when switching between semantic phases:

- **Triage → Implementation**: Backlog context is useless in code-change phase; drop it.
- **Implementation → Merge-waiting**: Code diff context is useless in CI-watch phase; drop it.
- **Merge-waiting → Next phase**: CI logs and merge status are transient; drop them.

Measured savings: reduces event count by 60–70% and tokens by 35–50% per compaction.
**Best-measured baseline**: 9.1M tokens, 101 events (207x ratio). Recent expensive runs had 68–84M tokens, 594–684 events (285x–434x ratio). Compaction at phase boundaries is the biggest win.

### 2. Reuse sprint templates instead of re-planning

Measured problem: 5 separate "Plan Next Sprint for Basecoat" sessions, averaging 39.5M tokens each (ratio 293x–498x).

**Solution**: Use persistent sprint template (`docs/templates/sprint-structure.md`) for reusable backlog structure.

- Load template once, reference by path in `/sprint-planner` calls
- Provide delta (issue changes) instead of full backlog
- Agent loads template structure and applies delta; no context reload

See: `docs/templates/sprint-structure.md` for the template and usage pattern.

Expected savings: 150M+ tokens/month (5 sessions × 39.5M tokens); 62% cost reduction per sprint-planning session (39.5M → ~15M tokens).

### 3. Avoid pasting instruction dumps; use file references

Measured problem: Recent sessions had user messages with 170k, 149k, 141k character pasted instruction/skill/config blocks.

**Cost**: A 170k character paste inflates every subsequent turn's context if the session stays live. That's re-sent on every agent call, every turn, until compaction.

**Solution**: Use file references only. Let agents load their own docs.

**Instead of:**

```text
[Paste 170k character SKILL.md or instruction file into chat]
```

**Do:**

```text
See: /skills/station-bottleneck-analyzer/SKILL.md (agent will load via `view`)
See: /.github/instructions/testing-validation.instructions.md (agent will load)
```

Expected savings: ~300x tokens per pasted block (170k chars × context reuse cost over 50+ turns = prevented 8.5M tokens).

#### `/compact` vs `/new` pivot rule

- Use `/compact` when staying in the same objective but changing phase.
- Use `/new` when objective/domain changes and prior context is mostly irrelevant.
- Before either command, persist the current canonical references (issue link, template path, or summary artifact path) so restart cost stays low.

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

#### Model-routing matrix for routine loops

| Work type | Default model | Upshift trigger |
|---|---|---|
| Status checks, run monitoring, branch/PR hygiene | gpt-5.4-mini or Haiku | Complex multi-system failure correlation |
| File scans, pattern lookups, lightweight triage | gpt-5.4-mini or Haiku | Ambiguous architecture/security tradeoffs |
| Deep refactor, architecture change, security reasoning | gpt-5.3-codex or stronger | N/A |

#### Auto/default model baseline and explicit upshift triggers

Start in Auto/default routing for routine workflows. Upshift model strength only when one or more of these triggers is present:

1. Cross-repository or cross-system reasoning with ambiguous root cause.
2. Security-sensitive review where subtle exploit paths must be analyzed.
3. Large refactors requiring strict behavior preservation across many touchpoints.
4. Architectural tradeoff decisions with long-lived platform impact.

Downshift again once the high-complexity segment is complete.

### MCP server overhead audit checklist

Before adding or using MCP-heavy flows in routine loops, verify:

1. The required data is not already available from local files or direct CLI commands.
2. Calls are batched to minimize round trips and repeated context transmission.
3. Returned payloads are scoped to only needed fields and row limits.
4. The workflow includes a fallback path if MCP is unavailable or slow.
5. The operation frequency is justified (avoid high-cadence polling without actionability).

Prefer direct repository tools (`view`, `glob`, `rg`) for local context and reserve MCP usage for external or system-of-record data.

## Fleet Patterns

### Direct Skill Targeting (Skip the Router)

Call specialized skills directly; skip router overhead (~500k tokens/call).

See `.github/instructions/routing-decision-tree.md` for the full intent → skill mapping (40+ entries).

| Intent | Direct Call |
|---|---|
| Triage issues | `/issue-triage` |
| Plan sprint | `/sprint-planner` |
| Fix build failure | `/build-failure-triage` |
| Clean branches | `/branch-hygiene-sweeper` |
| Review code | `/code-review` |

Expected savings: 46M tokens/mo (~500k per direct call × 96 router calls/mo).

### Single Kickoff + /tasks Monitoring

Instead of repeated router calls (96/mo), use:

1. Start once with the target agent or orchestrator
2. Monitor progress: `/tasks`
3. Steer with deltas: `Continue from issue #695; merge PRs after checks`

Reduces per-restart overhead by ~500k tokens.

### Delta Prompts

Avoid repeating boilerplate; use compact deltas:

**Before** (2KB):

```text
continue until blocked, i am stepping away, merge pacing text, skip replanning...
```

**After** (200 bytes):

```text
Continue from issue #695 state; only merge PRs after required checks; skip replanning.
```

### Retire Stale Schedules

Scheduled prompts (`/every`) that run >100 times/month cost ~150M tokens/mo.
After watchdog stops being actionable, stop it: `/every stop <schedule-id>`.

## Cost Observability & Auto-Compaction

Issue #1363 introduces an in-repo observability command and threshold checks:

### `/token-status` command

Run the command directly:

```bash
pwsh scripts/token-status.ps1 -InputTokens <n> -OutputTokens <n> -Events <n> -ElapsedMinutes <n>
```

JSON mode for automation:

```bash
pwsh scripts/token-status.ps1 -InputFile session-metrics.json -Json
```

The command reports:

- tokens sent so far (`inputTokens`)
- event count (`eventCount`)
- input/output ratio (`inputOutputRatio`)
- elapsed time (`elapsedMinutes`)
- estimated remaining budget (`estimatedRemainingBudget`)

### Auto-compact trigger thresholds

`autoCompactTriggered=true` when either threshold is crossed:

- event count `>= 400`
- input tokens `>= 50,000,000`

### Cost warning markers

`markers[]` emits `[COST-WARN] ...` entries when thresholds are crossed:

- ratio `>= 300x`
- events `>= 500`
- input tokens `>= 50,000,000`

These markers are designed for chat log visibility so agents can compact earlier and
delegate low-signal scans before sessions enter expensive ranges.

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
