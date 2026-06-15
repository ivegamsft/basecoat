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

### Ask mode vs Agent mode decision table

Use this table before starting work so mode selection is explicit, not implied.

| Situation | Preferred mode | Why | BaseCoat example |
|---|---|---|---|
| Single question, quick lookup, or one-file clarification | **Ask mode** | Avoids agent startup and orchestration overhead | "What does `.github/instructions/testing-validation.instructions.md` require for local validation?" |
| Small edit in one file with low ambiguity | **Ask mode** | Lower turn count and less context carry-over | Update one markdown section in `docs/guides/workflows-getting-started.md` |
| Multi-file change with generated artifacts or cross-reference updates | **Agent mode** | Better for coordinated edits and consistency checks | Refresh inventory docs plus `asset-manifest.json` and metadata artifacts |
| Command-heavy workflow with verification loops | **Agent mode** | Handles tool execution and iteration without main-thread churn | Run full validation/test scripts and fix breakages before PR |
| Broad triage/research across many modules or issues | **Agent mode** | Delegation and batching reduce repeated reads in the main thread | Backlog burndown scan across multiple issues/PRs |

If uncertain, start in **Ask mode** and switch to **Agent mode** when scope expands beyond a focused answer or single-step edit.

### Rich-file normalization before AI analysis

Prefer markdown or plain text artifacts before running AI-heavy analysis on rich/binary inputs.

1. Convert `.docx` and `.pdf` content to markdown or plain text summaries.
2. Convert `.pptx` decks to markdown slide outlines (title + bullets + notes).
3. Convert `.xlsx/.xls/.csv/.tsv` data to normalized tables or markdown summaries with only needed columns.
4. Store one canonical normalized artifact by path and reuse it across turns instead of repeatedly loading the original rich files.

This keeps prompts smaller, reduces repeated representation overhead, and stabilizes downstream reasoning quality.

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

Treat Auto/default routing as the baseline for routine workflows. Do not upshift for routine docs, simple lookups, git hygiene, or run monitoring. Upshift model strength only when one or more of these non-overlapping triggers is present:

1. **Ambiguous cross-system root cause**: cross-repository or cross-system reasoning where the failure path is not yet clear.
2. **Security-sensitive review**: subtle exploit paths, trust boundaries, or abuse cases must be analyzed.
3. **Large behavior-preserving refactor**: many touchpoints must change while preserving existing behavior.
4. **Architectural tradeoff decision**: long-lived platform or design choices require deeper reasoning.

Context reduction remains the primary cost lever: compact first when session history is bloated, and downshift again once the high-complexity segment is complete.

### MCP server overhead audit checklist

Run this audit at least **monthly** and again **before long fleet or burndown runs**.

Checklist:

1. **Inventory enabled servers/tools** in your current environment and note owner/purpose.
2. **Check recent usage** and mark servers that are inactive or rarely used for the target workflow.
3. **Disable unused servers** for the run to reduce schema/tool payload overhead.
4. **Verify required platform tooling remains enabled** (auth, repo, deployment, and compliance-critical tooling).
5. **Validate workflow health after changes** by running a representative task before broad execution.
6. **Review call patterns**: batch requests, scope returned fields/rows, and avoid high-cadence polling without actionability.

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

## Issue #1361 operational scorecard (acceptance enforcement)

For #1361 acceptance checks, run the backlog scorecard command with five measured
sessions:

```bash
pwsh scripts/backlog-efficiency-scorecard.ps1 -InputFile docs/templates/backlog-efficiency-sessions.example.json
```

Machine-readable output:

```bash
pwsh scripts/backlog-efficiency-scorecard.ps1 -InputFile <path-to-your-5-session-metrics.json> -Json
```

Required fields per session record:

- `sessionId`
- `inputTokens`
- `phaseCompactionApplied`
- `sprintTemplateUsed`
- `fileReferencesOnly`
- `delegatedScanOrTriage`

Pass criteria align to #1361 bullets:

1. At least 5 backlog sessions measured (`measurementReady=true`).
2. Average tokens for evaluated sessions is within 35M–45M (`targetMetByAverage=true`).
3. All four operational practices are compliant across evaluated sessions (`allPracticesCompliant=true`).
4. Combined acceptance state is `overallPass=true`.
