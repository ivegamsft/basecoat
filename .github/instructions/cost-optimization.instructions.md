---
description: "Session hygiene, fleet management, and token cost optimization patterns"
applyTo: "docs/**/*,.github/**/*"
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
2. Default to one dedicated session per issue/task, but avoid churn across related asks in the same repo/theme; use a new session when objective or deliverable changes.
3. At each phase switch (triage -> implementation -> merge waiting), run `/compact`.
4. If switching to a new domain (for example: sprint planning -> release operations), run `/new` and reload only relevant references.
5. Keep main-thread messages decision-focused; delegate scan/research work.
6. For attachment-heavy tasks, create one canonical summary artifact and reference it by path/link.
7. At events >= 300 or ratio >= 300x, run the context-rot triage checklist in
   `docs/operations/context-rot-runbook.md` before continuing.
8. After each `/compact`, scan the first three post-compact turns for restatement signals;
   if any appear, escalate to soft-fork (see `docs/operations/soft-fork-subtask-isolation.md`; Step 3 in the runbook).
9. **Token economics check:** Before large prompts, audit fresh input (highest cost lever). See `docs/guides/token-optimization.md` §11 for pricing tiers and optimization priority.

Branch/session churn guardrails:

- Treat frequent "new branch per small related ask" as a cost smell.
- Reuse warmed context for related work; do not restart only to clean up noise.
- Apply the rule: **compact before you fork; fork for isolation, not cleanup**.

### Token Economics at a Glance (Operator Patterns)

From `docs/guides/token-optimization.md` §11:

| Pricing Tier | Relative Cost | When to Optimize |
|---|---|---|
| Cached input | ~0.1–0.2x fresh | Only if repeated calls with same prefix (rare in CLI) |
| **Fresh input** | **1.0x baseline** | **Typically — highest ROI when input volume exceeds output** |
| Output | 2–3x fresh input | Second priority after fresh input |

**Observed heuristic (input-heavy workloads):** When input tokens greatly exceed output tokens — typical in agentic sessions — reducing fresh input often saves more in total cost than cutting output verbosity in half. At providers where output rates are 4–5x input rates, confirm your token mix before assuming this holds.

**Operator do/don't patterns:**

| Do | Don't |
|---|---|
| Load only files needed for this task (use glob patterns) | Load "whole context" upfront |
| Summarize repetitive logs/docs once, reference by path | Paste same excerpt across multiple turns |
| Compress multi-file context into 1–2K-token handoff | Pass raw output between agents |
| Use canonical templates (sprint structure, audit reports) | Re-create summaries per agent |
| Set output targets ("≤500 words"; structured not prose) | Allow unlimited output generation |
| Reference source files >5KB by path/line-range | Inline full file contents |
| Skip recap: "Reference prior turn 3 if needed" | Restate full context every turn |

**Quick decision tree:**

```text
Large prompt needed?
  → Scan your context for files >5KB
    → Replace with: "See: path/file.md (lines X–Y)"
  → Count repeated elements
    → Replace with: "Previously shown (turn N); reference if needed"
  → Any handoff from prior agent?
    → Create: 1–2K compressed summary, pass that
  → Output constraint set?
    → Add: "Limit output to <500 words"
```

**Cost savings checklist:**

- [ ] Fresh input audit: Any files the agent doesn't need? Remove.
- [ ] Handoff opportunity: Is this agent #2 or #3 seeing similar context? Summarize to 1–2K.
- [ ] Summarization opportunity: Any >10KB logs/docs? Compress; reference by path.
- [ ] Output constraint: Word limit or format specified? If not, add one.

For detailed guidance, examples, and provider-specific rates, see `docs/guides/token-optimization.md` §11.

### Keep-pattern defaults (workstream #2046)

These defaults are promoted to Keep status and should be treated as baseline
operator behavior:

| Default pattern | Minimum adoption target | Runbook |
|---|---|---|
| Phase-boundary compaction | >=80% of tracked runs | `docs/guides/kept-patterns/phase-boundary-compaction.md` |
| File-reference-only context loading | >=80% of tracked runs | `docs/guides/kept-patterns/file-reference-only-context.md` |
| Single kickoff plus `/tasks` monitoring | >=80% of tracked runs | `docs/guides/kept-patterns/single-kickoff-tasks-monitoring.md` |

Promotion and future-candidate review must follow:

- `docs/guides/keep-candidate-acceptance-checklist.md`

Branch/session churn guardrails:

- Treat frequent "new branch per small related ask" as a cost smell.
- Reuse warmed context for related work; do not restart only to clean up noise.
- Apply the rule: **compact before you fork; fork for isolation, not cleanup**.

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

Issue #1363 is implemented through an explicit operator loop:

1. Run `/token-status` at each phase boundary (triage -> implementation -> merge waiting).
2. If `events >= 400` **or** `tokens >= 50M`, run `/compact` immediately.
3. If ratio enters expensive zone (`>= 300x`), log a cost warning in chat and either compact or pivot.
4. If ratio stays high after one compact, start `/new` with only canonical references.

`/token-status` output contract:

```text
Token Status
- Tokens sent: <n>
- Event count: <n>
- Input/output ratio: <n>x
- Elapsed time: <duration>
- Estimated budget remaining: <n>
```

Warning thresholds:

- **Warning**: ratio >= 300x
- **Critical**: events >= 500
- **Hard stop**: events >= 594 or tokens >= 50M without compaction

Context-rot heuristics (check when Warning or Critical threshold is reached):

- Repeated restatement: >= 3 consecutive turns where the agent recaps prior context before acting.
- Contradictory outputs: output conflicts with a decision from the last 10 turns without an acknowledged pivot.
- Rising setup-to-action ratio: > 30% of the last 10 turns are recap rather than artifact production.
- Tool-call churn: >= 5 identical tool calls in a 10-turn window with no artifact change between calls.

Two or more active heuristics confirm rot risk. See the full detection and mitigation
runbook: `docs/operations/context-rot-runbook.md`.

Expected impact: agents self-correct mid-session instead of waiting for post-hoc review, reducing expensive-run frequency.

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
