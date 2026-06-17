# Token Optimization & Context Handling

Strategies for managing token budgets, compressing context, and handing off state between agents in a multi-agent system. Companion to [`model-optimization.md`](model-optimization.md) (model selection) and [`../architecture/multi-agent-orchestration-patterns.md`](../architecture/multi-agent-orchestration-patterns.md) (branch coordination).

For an operator-first rollout checklist that maps token controls to scoped instruction policy, see [`../reference/scoped-instructions.md#token-optimization-quick-start-for-instruction-operators`](../reference/scoped-instructions.md#token-optimization-quick-start-for-instruction-operators).

> **Tracking:** Issue [#42](https://github.com/IBuySpy-Shared/basecoat/issues/42)
> **GHCP-specific:** This guidance was developed and tested against GitHub Copilot (GHCP).
> If you are using Azure OpenAI, Anthropic API, AWS Bedrock, or another provider,
> model names, tier pricing, and rate limits will differ. See [Adapting for Other Providers](#adapting-for-other-providers).

Start with mode selection before loading context: [Ask mode vs Agent mode decision table](#ask-mode-vs-agent-mode-decision-table).
---

## Ask mode vs Agent mode decision table

Use this quick triage first; then apply the token techniques in the remaining sections.

| Situation | Preferred mode | Why | BaseCoat example |
|---|---|---|---|
| One question or one-file lookup | **Ask mode** | Lowest overhead for focused retrieval | Confirm expected command in `tests/run-tests.ps1` |
| Single-file, low-risk doc/config tweak | **Ask mode** | Fewer orchestration turns and less history bloat | Adjust one section in `docs/guides/workflows-getting-started.md` |
| Multi-file updates with generated artifacts | **Agent mode** | Coordinates edits + consistency checks end-to-end | Update inventory docs plus `asset-manifest.json` and `basecoat-metadata.json` |
| Tool-driven execution loop (tests/build/fix/retest) | **Agent mode** | Handles iterative command workflow efficiently | Run `pwsh tests/run-tests.ps1`, address failures, re-run |
| Cross-cutting triage or backlog sweep | **Agent mode** | Better batching/delegation for broad scan work | Review multiple open docs issues and prepare PR-ready changes |

If a task starts simple but expands in scope, switch from **Ask mode** to **Agent mode** immediately instead of carrying a large Ask-mode transcript.

---

## Operator Quick-Start Checklist (Issue #1436)

Use this checklist as the default operating path for token-efficient runs:

1. Start with file references only and compact at phase boundaries (`/compact`, `/new`) instead of carrying full pasted context.
2. Keep output tokens lean by default: short responses, small diffs, and depth only when risk or ambiguity requires it.
3. Choose Ask mode for direct, scoped work and Agent mode for multi-file execution, long-running commands, or broad research.
4. Start in Auto/default model routing, then upshift only when explicit complexity triggers are present.
5. Run an MCP overhead sanity pass before MCP-heavy loops (batch calls, limit fields, prefer local repo tools when possible).
6. Normalize rich files (slides, PDFs, spreadsheets, docs) into one markdown summary artifact before prompting downstream agents.

See also:

- [`.github/instructions/cost-optimization.instructions.md`](/.github/instructions/cost-optimization.instructions.md)
- [`.github/instructions/workflow-conventions.instructions.md`](/.github/instructions/workflow-conventions.instructions.md)
- [`../reference/scoped-instructions.md`](../reference/scoped-instructions.md)

---

## 1. Context Window Management Strategies

Every model has a finite context window. Treating it as unlimited leads to degraded output quality, truncated responses, and wasted spend.

### Know Your Limits

| Model | Context Window | Effective Limit | Notes |
|-------|---------------|-----------------|-------|
| claude-opus-4.6 | 200K tokens | ~160K usable | Reserve 20% for output generation |
| claude-sonnet-4.6 | 200K tokens | ~160K usable | Same reservation applies |
| gpt-5.3-codex | 200K tokens | ~160K usable | Code-optimized; large inputs degrade non-code reasoning |
| claude-haiku-4.5 | 200K tokens | ~160K usable | Fast but quality drops sharply past ~80K input |
| gpt-5.4-mini | 128K tokens | ~100K usable | Budget model; keep inputs under 60K for reliable output |

**Rule of thumb:** Reserve 20% of the context window for output. If you need 40K tokens of output, you have 160K minus 40K = 120K for input.

### Layered Context Loading

Load context in priority order rather than dumping everything at once:

1. **System instructions** — governance rules, role definition (~1–2K tokens)
2. **Task-specific instructions** — the immediate objective (~0.5–1K tokens)
3. **Critical reference files** — only files the agent must read to complete the task
4. **Supporting context** — examples, history, related docs (load only if budget remains)

Stop loading when you reach 60% of the effective limit. The remaining 40% covers agent reasoning and output.

---

## 2. Token Budget Allocation per Agent Role

Align token budgets with the model tier from [`model-optimization.md`](model-optimization.md):

| Agent Role | Model Tier | Recommended Input Budget | Max Output Budget | Rationale |
|------------|-----------|--------------------------|-------------------|-----------|
| architect | Premium | 80K | 40K | Deep reasoning needs room for chain-of-thought |
| security_analyst | Premium | 80K | 40K | Must analyze full code paths without truncation |
| reviewer / code-review | Reasoning | 60K | 20K | Diffs + context; output is structured comments |
| researcher | Reasoning | 80K | 30K | May ingest large docs; output is synthesis |
| backend-dev / frontend-dev | Code | 60K | 40K | Code generation needs generous output budget |
| sprint-planner | Reasoning | 40K | 20K | Structured decomposition, not large inputs |
| merge-coordinator | Fast | 20K | 10K | Small diffs, merge commands, status checks |
| config-auditor / watchdog | Fast | 30K | 5K | Scan-and-report; output is a short checklist |

### Budget Enforcement Pattern

```javascript
function enforceTokenBudget(prompt, maxInputTokens) {
  const estimated = estimateTokens(prompt);
  if (estimated > maxInputTokens) {
    return compressContext(prompt, maxInputTokens);
  }
  return prompt;
}
```

---

## 3. Prompt Compression Techniques

When context exceeds the budget, compress — don't truncate blindly.

### 3.1 Summarization

Replace large blocks with concise summaries. Use a fast-tier model (Haiku) to generate summaries before passing them to a higher-tier model.

```text
Before (2,400 tokens):
  Full git diff of 15 files with 200 changed lines

After (400 tokens):
  "Summary: 15 files changed across src/auth/ and src/api/.
   Key changes: JWT validation refactored, rate-limit middleware added,
   3 new API routes (/users, /sessions, /tokens). No deletions."
```

**Cost:** One Haiku summarization call (~0.02¢) can save 2,000 tokens on a Sonnet call (~0.6¢).

### 3.2 Selective Inclusion

Only include what the agent needs for its specific task:

| Agent Task | Include | Exclude |
|-----------|---------|---------|
| Code review | Changed files, diff hunks, test results | Unrelated source files, full history |
| Architecture | Interface definitions, dependency graph | Implementation bodies, test fixtures |
| Security scan | Auth code, input handling, config | UI components, styling, docs |
| Sprint planning | Issue list, velocity data, blockers | Source code, CI logs |

### 3.3 Truncation with Markers

When you must truncate, leave breadcrumbs so the agent knows context was removed:

```text
[FILE: src/auth/jwt.ts — 340 lines, showing lines 1-50 and 280-340]
[TRUNCATED: lines 51-279 contain helper functions — request full file if needed]
```

### 3.4 Reference by Pointer

Instead of inlining large files, reference them:

```text
For the full API schema, see: docs/api-schema.yaml (420 lines, ~8K tokens)
Key endpoints relevant to this task: POST /auth/login, DELETE /auth/session
```

### 3.5 Rich-file to Markdown Normalization

When inputs start as rich artifacts (PPTX, PDF, DOCX, XLSX), convert them to one markdown summary before using them as model context.

1. Extract only decision-relevant content (objectives, constraints, numbers, open risks).
2. Collapse repetitive material into one canonical summary file.
3. Link to the source artifact path or URL instead of pasting full extracted text.
4. Reuse that same markdown summary across turns and agents.

Suggested summary shape:

```markdown
## Source
- File: /path/to/source.ext
- Date: 2026-06-14

## Key Facts
- ...

## Decisions and Constraints
- ...

## Open Questions
- ...
```

This keeps attachment-heavy workflows token-stable and avoids duplicated extraction in downstream prompts.

---

## 4. Context Handoff Between Agents

When one agent's output becomes another agent's input, transfer only what matters.

### What to Pass

| Data | Pass? | Format |
|------|-------|--------|
| Task result / deliverable | ✅ Always | Full output |
| Decision rationale | ✅ Always | 2–3 sentence summary |
| Files created or modified | ✅ Always | File paths + brief description |
| Unresolved issues or blockers | ✅ Always | Structured list |
| Error messages encountered | ✅ If relevant | Exact error text |
| Full conversation history | ❌ Never | Summarize instead |
| Intermediate reasoning steps | ❌ Never | Only pass conclusions |
| Unchanged reference files | ❌ Never | Agent can load its own |

### Handoff Template

```markdown
## Agent Handoff: {source-role} → {target-role}

### Completed
- {what was done, 1-2 lines each}

### Artifacts
- `path/to/file.ts` — {what it contains}
- `path/to/test.ts` — {test coverage summary}

### Decisions Made
- {decision}: {rationale in one line}

### Open Items
- {anything the next agent must address}

### Context Files Needed
- {only files the next agent should load}
```

**Target size:** Handoff documents should be 500–1,500 tokens. If yours exceeds 2K tokens, compress further.

### Pipeline Example

```text
Architect (Opus, ~80K input)
  → produces: design doc + handoff (1.2K tokens)

Backend-Dev (Codex, ~60K input)
  → receives: handoff + design doc + relevant source files
  → produces: implementation + handoff (800 tokens)

Reviewer (Sonnet, ~60K input)
  → receives: handoff + diff + test results
  → produces: review comments + approval/rejection
```

---

## 5. Caching Strategies for Repeated Context

Avoid re-reading and re-tokenizing the same content across agent invocations.

### System Prompt Caching

Most providers cache system prompts across calls with identical prefixes. Structure prompts so the stable prefix (governance rules, role definition) stays constant:

```text
[CACHED — identical across all calls for this agent role]
  System instructions (governance.instructions.md)
  Role definition (agent .md file)

[VARIABLE — changes per invocation]
  Task-specific context
  File contents
  Conversation history
```

**Savings:** Anthropic's prompt caching charges ~10% of normal input cost for cached tokens. A 3K-token system prompt called 50 times saves ~135K billable tokens.

### Cross-Agent Shared Context

When multiple agents need the same reference (e.g., a project spec), load it once and pass a summary to subsequent agents rather than having each agent re-read the full document.

### Stale Context Invalidation

Cache keys should include:

- File content hash (not just path — files change)
- Branch name (context differs across branches)
- Timestamp with TTL (default: 15 minutes for active sprint work)

---

## 6. Measurement and Monitoring

### Token Usage Tracking

Track per-agent, per-invocation:

| Metric | How to Capture | Why It Matters |
|--------|---------------|----------------|
| Input tokens | Provider API response | Cost attribution |
| Output tokens | Provider API response | Cost attribution + quality signal |
| Cache hit tokens | Provider API response (if available) | Caching effectiveness |
| Context utilization | Input tokens ÷ effective window | Over 80% = risk of quality degradation |
| Compression ratio | Original tokens ÷ compressed tokens | Compression effectiveness |

### Cost Estimation Formula

```text
Per-invocation cost =
  (input_tokens × input_price_per_1M / 1,000,000)
  + (output_tokens × output_price_per_1M / 1,000,000)
  - (cached_tokens × cache_discount_per_1M / 1,000,000)
```

### Sprint-Level Budget

Estimate total sprint token usage:

```text
Sprint budget = Σ (agent_invocations × avg_tokens_per_invocation × cost_per_token)
```

Example for a 10-issue sprint:

- 10 planning calls (Sonnet, ~40K input, ~10K output) ≈ 500K tokens
- 30 implementation calls (Codex, ~60K input, ~30K output) ≈ 2.7M tokens
- 20 review calls (Sonnet, ~40K input, ~10K output) ≈ 1M tokens
- 40 automation calls (Haiku, ~20K input, ~5K output) ≈ 1M tokens
- **Total: ~5.2M tokens per sprint**

### Alerts

Set thresholds to catch runaway usage:

- Single invocation exceeds 150K input tokens → warn
- Agent role exceeds 2× its average daily usage → investigate
- Sprint total exceeds budget by 20% → pause and review

---

## 7. MCP Server Audit for Token Overhead Control

Tool schemas and capability catalogs increase per-step context size. Keep MCP footprint intentional.

### Recommended Cadence

- Run this audit **monthly** as routine hygiene.
- Run it again **before long fleet runs** (for example, backlog burndown, broad triage, or multi-PR waves).

### Audit Checklist

| Step | What to do | Why it saves tokens |
|---|---|---|
| Inventory | List enabled MCP servers and primary tools used in the run | Reveals unnecessary schema surface area |
| Usage check | Review recent usage and mark inactive/rarely-used servers | Prevents paying repeated context cost for idle tools |
| Disable unused | Temporarily disable servers not needed for the current objective | Reduces prompt/tool metadata overhead on each step |
| Verify required | Confirm required platform tooling remains enabled (auth/repo/deploy/compliance-critical) | Prevents breaking core workflows while optimizing |
| Smoke test | Run one representative task after changes | Catches accidental tool disablement early |

### Safe Process Notes

- Disable only servers that are unused for the target workflow.
- Keep required platform tooling enabled.
- Document the audit outcome so the next operator can restore or reuse the same baseline.
- Prefer workflow-neutral steps (inventory, usage, disable, verify) rather than IDE-specific controls.

---

## 8. Instruction File Sizing

Instruction files (`.instructions.md`, `.agent.md`) are loaded into every invocation. Oversized instructions waste budget on every call.

| File Type | Target Size | Max Size | Tokens (est.) |
|-----------|-------------|----------|---------------|
| `.instructions.md` | 1–3 KB | 5 KB | ~500–1,500 |
| `.agent.md` | 2–4 KB | 6 KB | ~800–2,000 |
| Governance instructions | 3–5 KB | 8 KB | ~1,200–2,500 |

### Sizing Guidelines

- **One concern per file.** Split multi-topic instructions into separate files.
- **Link, don't inline.** Reference detailed docs by path instead of copying content.
- **Prune examples.** One good example beats three redundant ones.
- **Audit quarterly.** Remove outdated rules that no longer apply.

---

## 9. Practical Examples with Token Counts

### Example A: Code Review — Well-Optimized

```text
System prompt (governance + reviewer role):     1,800 tokens
Task instructions:                                 400 tokens
Diff (3 files, 120 lines changed):              2,200 tokens
Test results summary:                              300 tokens
───────────────────────────────────────────────
Total input:                                     4,700 tokens
Output (review comments):                        1,200 tokens
Model: claude-sonnet-4.6
Estimated cost:                                   ~$0.02
```

### Example B: Code Review — Unoptimized

```text
System prompt (full governance + all instructions): 4,500 tokens
Full conversation history (15 turns):              12,000 tokens
All source files in the repo:                      45,000 tokens
Full CI log output:                                 8,000 tokens
───────────────────────────────────────────────
Total input:                                      69,500 tokens
Output (same review comments):                     1,200 tokens
Model: claude-sonnet-4.6
Estimated cost:                                    ~$0.23
```

**Savings: 91% cost reduction** by loading only what the agent needs.

### Example C: Architect → Backend-Dev Handoff

```text
Architect output (full):                          8,000 tokens
Handoff document (compressed):                    1,200 tokens
Backend-dev loads: handoff + 3 source files:      6,400 tokens
───────────────────────────────────────────────
Backend-dev total input:                          7,600 tokens
Without handoff (re-reads everything):           35,000 tokens
Savings:                                            78%
```

---

## 10. Task Complexity, Turn Budgets, and Adaptive Learning

Agent work has a cost that goes beyond tokens — it also consumes turns. Turns compound: each one adds history to the context window, narrows decision space, and raises the cost of a wrong approach. This section defines how to classify tasks, budget turns, and convert experience into reusable memory.

### 9.1 Complexity Classification

Classify each task before starting. State the class in your plan or at the top of your first response.

| Class | Definition | Typical indicators | Soft turn budget |
|---|---|---|---|
| **Routine** | Pattern fully covered by existing instructions or memory | "We have an instruction for this", existing template matches | ≤ 3 turns |
| **Familiar** | Similar to prior work but with new variables or constraints | "We've done something like this", partial memory match | ≤ 5 turns |
| **Novel** | No prior coverage; encountering this pattern for the first time | No matching instruction, no memory hit, new tool/API/pattern | Estimate N turns upfront |

For Novel tasks, state the estimated turn cost at task start:

```text
Task: Integrate Azure Service Connector with App Configuration
Class: Novel — no prior Service Connector instruction exists
Estimated turns: 6 (learning cost: ~3 for discovery, ~3 for implementation + validation)
```

**Learning cost amortization:** A Novel task that succeeds becomes Familiar the next time. Familiar tasks that are done repeatedly become Routine. Memory is the mechanism — see §9.3.

### 9.2 Failure Protocol — Stuck After 5 Turns

If a task has consumed more than 5 turns **and** there has been no measurable forward progress, stop. Do not continue with more of the same approach.

#### What counts as forward progress?

| Signal | Counts? |
|---|---|
| A new test passes that did not pass before | ✅ Yes |
| A new error class is resolved (not just a different message for the same root cause) | ✅ Yes |
| A file reaches its intended target state | ✅ Yes |
| A blocker is identified and removed | ✅ Yes |
| The same error appears with different output | ❌ No |
| More lines of code added without test validation | ❌ No |
| Escalating to a higher-tier model without changing the approach | ❌ No |

#### When stuck

1. **Log to memory.** Call `store_memory` with:
   - Task description (what was being attempted)
   - Approach tried (summarize the strategy, not the code)
   - Failure mode (exact error, logical dead-end, or missing capability)
   - Blocking signal (what specifically is preventing progress)

2. **Reassess, don't escalate.** Change the approach before changing the model tier. Common pivots:
   - Break the task into smaller independently-verifiable units
   - Load docs or examples that were previously skipped to save tokens
   - Invert the approach (bottom-up instead of top-down, or vice versa)
   - Consult memory for similar prior failures

3. **Escalate model tier only as a last resort**, and only when the problem genuinely requires deeper reasoning — not just more attempts.

#### Early warning: the 80/50 rule

At 80% of your turn budget, if you have less than 50% progress toward the goal, pause and reassess. Don't wait until fully stuck.

```text
Turn budget: 5
Current turn: 4 (80%)
Progress: 1 test passing of 4 required (25%)
→ Pause. Reassess before turn 5.
```

### 9.3 Success Protocol — Learning Reinforcement

When a task completes within its turn budget **and** test validation passes, evaluate whether the solution involved a non-obvious pattern.

**Reinforce when:**

- The solution required a discovery that no existing instruction covers
- The approach was non-obvious and could save future agents 2+ turns
- A specific error was encountered and resolved in a reusable way

**Skip when:**

- The task followed an existing instruction exactly
- The solution is boilerplate (adding a route, writing a standard test, etc.)
- The memory fact would duplicate existing instruction content

**What to store:**

```text
Subject:    <topic area>
Fact:       <pattern or rule, ≤200 chars>
Citations:  <file:line or "User input: ..." or "Validated in task X">
Reason:     <why this will help future tasks; what turns it saves>
```

**Good example:**

```text
Subject:    gh-aw compilation
Fact:       gh aw safe-outputs: add-labels and add-comment take no sub-properties.
            allowed-labels belongs under create-issue, not add-labels.
Citations:  .github/workflows/issue-triage.md — Sprint 11 compile iteration
Reason:     This error burned 2 turns on Sprint 11. Any future agentic workflow
            author will hit it immediately without this memory.
```

**Bad example (too generic — skip):**

```text
Fact: Use TypeScript for new files.
→ Already in instructions. Skip.
```

### 9.4 Turn Accounting Summary

```text
Before task:
  Classify: Routine / Familiar / Novel
  If Novel: state estimated turn budget

During task:
  Track actual turns vs. budget
  At 80% budget / <50% progress: reassess

On failure (>5 turns, no progress):
  store_memory(failure pattern)
  change approach or escalate

On success (within budget + tests pass):
  if novel pattern: store_memory(solution pattern)
  classification → drops one level (Novel→Familiar, Familiar→Routine)
```

---

## 11. From the Field: BaseCoat Sprint Experience

These examples come from BaseCoat's own development sprints. They illustrate how
the strategies in §1–9 play out in practice.

### Context Loading: The Cost of Speculative Reads

**What happened:** In early sprints, the explore skill pattern was: read the entire
`agents/` directory to understand the repo state. At 77 agents (~400 tokens each),
this consumed ~30K tokens before any task work started.

**What changed:** The hot-index pattern. The L2 memory index (`memory-index.instructions.md`)
loads a curated summary (~1,500 tokens) of all key facts about the repo. This
replaces the full directory scan for 80% of tasks. The other 20% (Novel tasks
that need specific agent details) load only the targeted agent files.

**Measured impact:** Task startup dropped from ~30K tokens (full scan) to
~3K tokens (hot index + targeted load). On a sprint with 30 agent invocations,
this saves ~810K tokens.

---

### Turn Budget: The 5-Turn Recovery Pattern

**What happened:** During Sprint 19, an agent was tasked with wiring
`check-coherence.ps1` into CI. It consumed 7 turns and produced no working
configuration. The agent kept modifying the workflow YAML — changing indentation,
restructuring steps — but the root problem was that the script exits 0 by default
and CI never knew it had run with violations.

**The 80/50 signal was ignored:** At turn 4 (80% of a ≤5 budget), the agent had
1 of 3 required checks passing (33% progress). The correct move was to pause
and reassess.

**Resolution in turn 8:** Changed approach — instead of fixing the workflow, added
`-Strict` to the script call in `run-tests.ps1`. The same tests that had been
passing now surfaced the violations. Three lines of change instead of 50.

**Pattern confirmed:** At 80% of turn budget with <50% progress, the approach is
wrong. More turns with the same approach do not fix this.

---

### Instruction Sizing: When Instructions Become Context Debt

**Observation across Sprint 23–24:** The governance instruction file
(`instructions/basecoat-20-lang-governance.instructions.md`) grew to 8KB+ (estimated ~2,500 tokens).
Because it has `applyTo: "**/*"`, it loads on every agent invocation. Across a
30-invocation sprint, the governance instruction alone accounts for ~75K tokens.

**What this means:** Every 1KB added to a global instruction file costs ~750K
tokens per year at BaseCoat's sprint velocity (~300 invocations/month).
Global instruction files have a much higher amortized cost than targeted ones.

**Rule reinforced:** Global instructions (`applyTo: "**/*"`) should contain only
invariant rules. Domain-specific guidance belongs in scoped instruction files
(`applyTo: "agents/**"`, `applyTo: "*.yml"`).

---

### Compression: Haiku for Summarization, Sonnet for Analysis

**Pattern from audit sprint:** Four audit background agents each read 50–80 files
and returned structured reports (150–200s wall time). All four used the Haiku-class
explore model. All four produced accurate results. Total token cost: approximately
the same as one Sonnet invocation with the same context.

**The lesson:** "Reading and organizing" is a Fast-tier task even when the output
matters. "Analyzing and deciding based on what you read" is a Reasoning-tier task.
The audit agents did the former; the session's main agent did the latter using the
audit reports as compressed input (~15K tokens total from four Haiku agents, vs.
~80K tokens if the Sonnet session had read all the files directly).

**Template for expensive research:**

```text
Fast agent (Haiku): read files, grep patterns, count things, organize findings
  → output: structured report (~2K tokens)

Reasoning agent (Sonnet): receive structured reports, analyze, decide, act
  → input: N × 2K tokens from fast agents
  → avoids: N × 30K tokens of direct file reading
```

---

## Adapting for Other Providers

This guide focuses on GitHub Copilot (GHCP). If your team routes agents to a
different provider, model names, tier pricing, and rate limits will differ:

| Provider | Model tier equivalent | Rate limit difference | Billing unit |
|---|---|---|---|
| Azure OpenAI | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | TPM/RPM per deployment | Per token |
| Anthropic API | Opus ~= Premium, Sonnet ~= Standard, Haiku ~= Fast | Per-minute limits | Per token |
| AWS Bedrock | On-demand vs. provisioned | Regional quotas | Per token |
| OpenAI API | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | Tier-based RPM/TPM | Per token |

Adjust rate-limit constants and budget thresholds to match the provider's documented
limits. For UBB cost estimation and monitoring guidance, see
[ubb-token-guidance.md](ubb-token-guidance.md).

---

## 12. Sprint Planning & Re-Planning Cost Reduction

### The Problem: Planning Sessions Are Expensive

Measured from BaseCoat live sessions:

- **5 separate "Plan Next Sprint" sessions**: ~39.5M tokens each (ratio 293x–498x input/output)
- **Total annual cost**: 150M+ tokens from re-planning alone
- **Root cause**: Each session reloads full backlog context from scratch instead of reusing structure

### The Solution: Persistent Sprint Template

Use `docs/templates/sprint-structure.md` (or equivalent) as a reusable backlog skeleton.

**Reference, don't reload:**

Instead of:

```text
/sprint-planner
I need to plan the next sprint. Here's the full backlog [170k characters of issues]...
[Context bloat begins, history accumulates, tokens pile up]
```

Do:

```text
/sprint-planner  
Reference: docs/templates/sprint-structure.md
Delta from Sprint 30: [issue list changes only, ~10 lines]
New priorities: #1234, #5678
Moved out: #9999 (done), #8888 (defer)
```

**Measured impact**: ~39.5M → ~15M tokens per sprint-planning session (62% reduction).

### Template Structure (Reusable Pattern)

Every sprint uses this structure:

```text
## Sprint Metadata
- Sprint ID
- Duration
- Goals

## Backlog Categories
### P1 Blockers (0–3 items)
### P2 Medium (8–15 items)
### P3 Low (0–5 items)

## Changes from Prior Sprint
- Moved In (new priorities)
- Moved Out (deferred / completed)
- Reordered (within P2/P3)

## Notes for Planner
- Bulk tasks can run in parallel
- Resource constraints
- Known blockers
```

When planning Sprint 31, 32, etc., reference this template and provide only the delta.

### Bulk Agent Updates Pattern

For mechanical agent updates (model downshift, scope docs, bulk refactoring), run in parallel via background agents instead of sequentially in the main session.

**Measured from Sprint 31:**

- Sequential execution: ~40 minutes + context overhead
- Parallel execution (background agents): ~30 minutes, main session thin

This pattern works for any bulk task that doesn't require cross-file orchestration.

### Cost Baseline Targets for Sprints

Based on measured BaseCoat sprints:

| Metric | Target | Good | Expensive | Notes |
|--------|--------|------|-----------|-------|
| **Planning session** | 15–20M tokens | <20M | >40M | Use template; avoid re-planning |
| **Event count (full sprint)** | 150–200 events | <200 | >400 | Compact at phase boundaries |
| **Input/output ratio** | 207x–250x | <250x | >400x | Ratio = sum inputs / sum outputs |
| **Pasted instruction size** | <10KB per msg | <10KB | >100KB | Reference files; no pastes |
| **Re-plan occurrences** | 1 per sprint | 1 | >2 | Template reuse prevents re-planning |

### Sprint Checklist: Before Calling `/sprint-planner`

- [ ] Load template: `docs/templates/sprint-structure.md`
- [ ] Prepare delta (not full backlog)
- [ ] List P1 blockers (if any)
- [ ] Note bulk tasks suitable for parallelization
- [ ] Reference prior sprint (don't reload)
- [ ] Plan to log the finished session in `.github/backlog-session-metrics.json`
- [ ] Regenerate `docs/reference/BACKLOG_SESSION_SCORECARD.md` after the run

---

## 13. Agent Model Recommendations (Updated Sprint 31)

### Routine Agents Downshifted to gpt-5.4-mini (Cost: ~$50–100/mo savings)

Based on Sprint 31 empirical testing, the following agent categories are safe to downshift from `claude-sonnet-4.6` to `gpt-5.4-mini`:

| Category | Agents | Rationale | Cost Impact |
|----------|--------|-----------|-------------|
| **Triage & Routing** | issue-triage, dependency-blocker-monitor, orphaned-pr-cleanup, escalation-router | Systematic label/pattern matching (rules-based) | ~25–30% per call |
| **Audit & Compliance** | instruction-auditor, security-monitor, sprint-closeout-auditor | Scan for compliance, validate schema, report | ~15–20% (audit tasks are deterministic) |
| **Cleanup & Maintenance** | branch-hygiene-sweeper, run-history-cleanup | Delete by age/status, FIFO retention | ~25–30% per call |
| **Log Analysis** | broken-build-troubleshooter, ci-failure-escalation | Pattern-match error logs, categorize | ~20–25% per call |

**Model tier equivalents:**

- `claude-sonnet-4.6` → reasoning/heavy tasks
- `gpt-5.4-mini` → routine triage, audit, cleanup, log parsing
- `claude-haiku-4.5` → already optimal for fast I/O (keep as-is)

**Exception:** Agents performing novel analysis, security decisions, or architecture work should remain on `claude-sonnet-4.6` or `claude-opus`.

---

## Related References

- [`model-optimization.md`](model-optimization.md) — Model tier matrix and cost considerations
- [`../architecture/multi-agent-orchestration-patterns.md`](../architecture/multi-agent-orchestration-patterns.md) — Branch coordination for parallel agents
- [`../reference/scoped-instructions.md`](../reference/scoped-instructions.md) — Quick-start checklist and rollout policy for scoped instruction operators
- [`instructions/basecoat-20-lang-governance.instructions.md`](/instructions/basecoat-20-lang-governance.instructions.md) — Section 10: Token and Model Awareness
- [`.github/instructions/cost-optimization.instructions.md`](/.github/instructions/cost-optimization.instructions.md) — Operator defaults, model upshift triggers, and MCP overhead checklist
- [`.github/instructions/workflow-conventions.instructions.md`](/.github/instructions/workflow-conventions.instructions.md) — Ask vs Agent mode policy and transition hygiene
- [`../reference/scoped-instructions.md`](../reference/scoped-instructions.md) — Scope patterns that prevent universal instruction bloat
- [`../templates/sprint-structure.md`](../templates/sprint-structure.md) — Reusable sprint planning template (reduces re-planning cost 62%)
- [`../reference/BACKLOG_SESSION_SCORECARD.md`](../reference/BACKLOG_SESSION_SCORECARD.md) — Latest 5-session scorecard for the 35-45M backlog target
- Issue [#42](https://github.com/IBuySpy-Shared/basecoat/issues/42) — Tracking issue for token optimization
- Issue [#44](https://github.com/IBuySpy-Shared/basecoat/issues/44) — Token budget and cost attribution
- Issue [#1361](https://github.com/IBuySpy-Shared/basecoat/issues/1361) — Efficiency target: reduce backlog runs 68→35-45M tokens
- Issue [#1362](https://github.com/IBuySpy-Shared/basecoat/issues/1362) — Sprint template to eliminate re-planning cost
- [`ubb-token-guidance.md`](ubb-token-guidance.md) -- UBB billing model, cost estimation, monitoring
