# Agent Model Optimization Guide

Choosing the right LLM for each agent role is a cost-performance tradeoff. Default-to-cheapest wastes time on retries and low-quality output; default-to-premium wastes money on tasks that don't need it. This guide provides a principled tier matrix so every agent runs on the model that matches its cognitive demand.

> **GHCP-specific:** This guidance was developed and tested against GitHub Copilot (GHCP).
> If you are using Azure OpenAI, Anthropic API, AWS Bedrock, or another provider,
> model names, tier pricing, and rate limits will differ. See [Adapting for Other Providers](#adapting-for-other-providers).
> **Discovery context:** During the app-migration-with-ai Sprint 2, all agents defaulted to Haiku. Architect and security tasks underperformed significantly, requiring manual rework. This guide codifies the lessons learned.

---

## Tier Matrix

| Role | Recommended Model | Tier | Rationale |
|------|------------------|------|-----------|
| architect | claude-opus-4.7 | Premium | High-stakes design decisions requiring deep, multi-step reasoning |
| security_analyst | claude-opus-4.7 | Premium | Security analysis requires thorough reasoning and cannot afford shortcuts |
| reviewer / code-review | claude-sonnet-4.6 | Reasoning | Nuanced code analysis but not premium-tier complexity |
| researcher | claude-sonnet-4.6 | Reasoning | Analysis and synthesis require good reasoning depth |
| qa / manual-test-strategy / exploratory-charter / strategy-to-automation | claude-sonnet-4.6 | Reasoning | Structured thinking, edge case identification, test design |
| backend-dev / frontend-dev / middleware-dev / data-tier / code | gpt-5.3-codex | Code | Code-optimized model tuned for generation, refactoring, and debugging |
| sprint-planner / release-manager / project-onboarding | claude-sonnet-4.6 | Reasoning | Planning and decomposition need good reasoning, not raw code output |
| new-customization | claude-sonnet-4.6 | Reasoning | Deciding between customization types requires structured reasoning |
| merge-coordinator / rollout-basecoat / config-auditor | claude-haiku-4.5 | Fast | Routine automation with well-defined steps — speed and cost matter most |
| agent-watchdog / sprint-demo | gpt-5.4-mini | Fast | Simple automation tasks with minimal reasoning requirements |

---

## Tier Definitions

### Premium — `claude-opus-4.7`

Use for tasks where a mistake is expensive or irreversible: architecture decisions, security reviews, threat modeling, compliance analysis. These tasks require deep multi-step reasoning, weighing tradeoffs, and producing output that will be trusted without a second opinion.

**Cost:** ~5× Sonnet. Use deliberately. Variants: `claude-opus-4.7-high` (extended chain-of-thought), `claude-opus-4.6` (proven fallback).

### Reasoning — `claude-sonnet-4.6`

The workhorse tier. Use for tasks that require genuine analysis — code review, test strategy, planning, research — but where the output will be reviewed by a human or validated by CI before it matters. Good balance of quality and cost.

**Cost:** Baseline reference tier.

### Code — `gpt-5.3-codex`

Use for code generation, refactoring, migration, and debugging. This model is specifically optimized for code tasks and outperforms general-purpose models on implementation work. Not ideal for prose-heavy analysis or strategic reasoning.

**Cost:** Comparable to Sonnet. Value comes from code-specific optimization.

### Fast — `claude-haiku-4.5` / `gpt-5.4-mini`

Use for well-defined, repetitive tasks: file scanning, config auditing, branch operations, rollout scripts, simple automation. The task should have clear inputs, deterministic steps, and easily validated output. If the agent needs to "think," it probably needs a higher tier.

**Cost:** ~10× cheaper than Sonnet. Use aggressively for routine work.

---

## When to Override the Default

Override the recommended model when:

| Situation | Override Direction | Example |
|-----------|-------------------|---------|
| Task is unusually complex for the role | ↑ Upgrade one tier | A backend-dev task involving a complex distributed transaction → claude-sonnet-4.6 |
| Task is unusually simple for the role | ↓ Downgrade one tier | A code-review of a single-line typo fix → claude-haiku-4.5 |
| Output will not be human-reviewed | ↑ Upgrade one tier | Automated security scan running unattended → claude-opus-4.7 |
| Output will be heavily reviewed | ↓ Downgrade one tier | Draft PR description that a human will rewrite anyway → claude-haiku-4.5 |
| Budget is constrained | ↓ Use minimum viable tier | See the Minimum column in each agent's `## Model` section |
| Task requires cross-domain reasoning | ↑ Upgrade one tier | A backend-dev task that also requires security analysis → claude-sonnet-4.6 |

---

## Cost Considerations

Rough relative cost per million tokens (input + output blended):

| Model | Relative Cost | Best For |
|-------|--------------|----------|
| claude-opus-4.7 | 5.0× | Architecture, security, high-stakes reasoning |
| claude-sonnet-4.6 | 1.0× (baseline) | Analysis, review, planning, test strategy |
| gpt-5.3-codex | ~1.0× | Code generation, refactoring, debugging |
| claude-haiku-4.5 | 0.1× | Routine automation, scanning, simple tasks |
| gpt-5.4-mini | 0.08× | Simple automation, monitoring, formatting |
| gpt-4.1 | 0.05× | Binary checks, guardrails, cheapest |

**Rule of thumb:** If 10 Haiku runs cost less than 1 Sonnet run _and_ the Haiku output is good enough, use Haiku. If a single Opus run saves you from a production incident, use Opus.

---

## Consumer Configuration

### In agent `.md` files

Each agent file includes a `## Model` section:

```markdown
## Model
**Recommended:** claude-sonnet-4.6
**Rationale:** Analysis tasks need good reasoning depth
**Minimum:** claude-haiku-4.5
```

- **Recommended** — use this model by default
- **Rationale** — why this tier was chosen (helps future reviewers)
- **Minimum** — the cheapest model that can still complete the task acceptably; use when budget is constrained or the specific invocation is simple

### In orchestration code

When spawning agents programmatically, pass the model as a parameter:

```javascript
// Use the recommended model from the agent's ## Model section
const result = await spawnAgent({
  role: 'backend-dev',
  model: 'gpt-5.3-codex',   // from agents/backend-dev.agent.md
  prompt: taskDescription
});
```

### In CI/CD pipelines

Set model selection via environment variables:

```yaml
env:
  AGENT_MODEL_BACKEND: gpt-5.3-codex
  AGENT_MODEL_REVIEW: claude-sonnet-4.6
  AGENT_MODEL_SECURITY: claude-opus-4.6
  AGENT_MODEL_DEFAULT: claude-haiku-4.5
```

---

## Agent Template Pattern

When creating a new agent, include the `## Model` section in the `.agent.md` file. Place it immediately before the `## Governance` section:

```markdown
## Model
**Recommended:** <model-name>
**Rationale:** <one line explaining why this tier>
**Minimum:** <cheapest acceptable model>
```

Choose the tier based on the cognitive demand of the agent's primary task:

| Cognitive Demand | Tier | Model |
|-----------------|------|-------|
| Deep multi-step reasoning, high-stakes decisions | Premium | claude-opus-4.6 |
| Analysis, structured thinking, planning | Reasoning | claude-sonnet-4.6 |
| Code generation, refactoring, implementation | Code | gpt-5.3-codex |
| Routine steps, scanning, simple automation | Fast | claude-haiku-4.5 or gpt-5.4-mini |

---

## Lessons from Production

These examples come from BaseCoat's own sprint history. Each led to a concrete
change in the tier matrix or override rules above.

### Sprint 2: The Haiku Default Failure

**What happened:** All agents in Sprint 2 defaulted to `claude-haiku-4.5`. The
architect agent was tasked with designing a multi-region failover strategy. The
output was structurally correct but shallow — it described patterns without
evaluating tradeoffs, skipped durability edge cases, and required two rounds of
manual rework before the design was usable.

**Root cause:** Haiku lacks the chain-of-thought depth for multi-step reasoning
under uncertainty. Architect tasks are not "follow a template" tasks — they
require weighing contradictory constraints.

**What changed:** The tier matrix now assigns `architect` to Premium unconditionally,
with an explicit override note: "never downgrade below Reasoning even under budget
pressure."

**Signal to watch for:** If an agent produces output that is structurally correct but
feels thin — correct vocabulary, missing substance — it is likely under-tiered.

---

### Sprint 19: Haiku for Scanning, Not for Judgment

**What happened:** A `config-auditor` agent using `claude-sonnet-4.6` was processing
100+ config files per sprint. The cost was material. Switching to `claude-haiku-4.5`
produced identical results for the scan phase (does this value match this pattern?)
but failed on the judgment phase (is this config safe given the deployment context?).

**Resolution:** Split the agent into two steps — Haiku for the scan loop, Sonnet for
the final risk assessment. Cost dropped ~75% with no quality regression on the
judgment output.

**Pattern:** Scanning is a Fast-tier task. Judgment on scan results is a Reasoning-tier
task. If your agent does both in one pass, split it.

---

### Sprint 24: Fleet Rate Limit Discovery

**What happened:** A sprint launch dispatched 5 concurrent background agents. After
~90 seconds, three returned 429 errors and stopped mid-task. Retrying immediately
produced the same result. The sprint had to be restarted with a manual wave pattern.

**What we learned:**
- Enterprise Copilot API limits concurrent sessions, not just requests-per-minute
- 3 concurrent agents = safe ceiling
- 4 = risky depending on org activity at the time
- 5+ = near-certain 429 within 60–90 seconds
- Recovery: wait 90 seconds, then restart with reduced concurrency

**What changed:** Added a 15-second inter-agent stagger to all sprint kickoff scripts.
Wave size capped at 3 in `sprint-kickoff-safe.ps1`. The rate-limit guidance doc was
updated to cover AI/Copilot fleet limits (previously only covered GitHub REST API).

**Model connection:** Running 5 agents on Premium models worsens this. Premium models
use more server-side resources. If you must run 5+ agents, use Fast/Code tier where
possible to reduce per-agent resource consumption.

---

### Ongoing: Explore Agents Are Correctly Tiered at Fast/Haiku

**Observation:** The BaseCoat audit agents (`audit-asset-counts`, `audit-ci-governance`,
`audit-philosophy-adr`, `audit-scripts-memory`) each ran for 150–200 seconds using the
Haiku-class explore agent. All four produced accurate, well-structured reports.

**Why this works:** Explore agents read files, grep patterns, and report findings. This
is scanning and synthesis from structured data — a Fast-tier task. They do not need
multi-step reasoning or judgment. Sonnet would have cost ~10× more per agent for no
improvement in output quality.

**Rule confirmed:** Match tier to the cognitive demand of the task, not the perceived
importance of the output. An audit report can be important without requiring Premium
reasoning to produce.

---

## Adapting for Other Providers

The tier matrix above uses GitHub Copilot (GHCP) model names. If your agents target
a different provider, map the tiers as follows:

| Provider | Model tier equivalent | Rate limit difference | Billing unit |
|---|---|---|---|
| Azure OpenAI | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | TPM/RPM per deployment | Per token |
| Anthropic API | Opus ~= Premium, Sonnet ~= Standard, Haiku ~= Fast | Per-minute limits | Per token |
| AWS Bedrock | On-demand vs. provisioned | Regional quotas | Per token |
| OpenAI API | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | Tier-based RPM/TPM | Per token |

Substitute provider-specific model names in agent `## Model` sections and CI/CD
environment variables. Cost considerations and override logic remain the same.
For UBB billing and monitoring guidance, see [ubb-token-guidance.md](ubb-token-guidance.md).

---

## Related References

- `instructions/governance.instructions.md` — Section 10 covers model awareness policy
- `instructions/token-economics.instructions.md` — Turn budget classification and fast-path routing
- Individual agent files in `agents/` — each contains a `## Model` section
- [`token-optimization.md`](token-optimization.md) — Context window management and budget allocation
- [`ubb-token-guidance.md`](ubb-token-guidance.md) -- UBB billing model, cost estimation, alert thresholds