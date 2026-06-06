# UBB Token Guidance for BaseCoat Fleet Dispatch

This guide covers Usage-Based Billing (UBB) for GitHub Copilot and how BaseCoat
fleet dispatch affects cost. It is intended for teams running multi-agent sprints
against a GitHub Copilot Enterprise subscription.

---

## What Is UBB and When Does It Apply?

GitHub Copilot is available under two billing models:

| Model | Who Pays | Unit | When It Applies |
|---|---|---|---|
| Per-seat | Org admin / IT | Fixed monthly per user | Standard Copilot Enterprise or Business license |
| Usage-Based Billing (UBB) | Org / team | Per token consumed | Copilot API usage beyond seat entitlement, or when the org enables UBB metering |

**UBB applies when:**

- Your org has enabled token-metered billing for Copilot API calls.
- You are using the Copilot API programmatically (fleet dispatch, CI agents, automation pipelines) rather than interactively through the IDE.
- You exceed included API quota bundled with per-seat licenses.

**UBB does NOT apply when:**

- All Copilot usage is interactive (IDE, chat, code completion) within the per-seat entitlement.
- Your org has not enabled UBB and has not exceeded any included quota.

Check with your GitHub Enterprise admin or billing dashboard to confirm which model is active for your org.

---

## How BaseCoat Fleet Dispatch Affects UBB Cost

Each agent turn in a BaseCoat sprint consumes tokens. Cost accumulates from three factors:

### Turns

Each agent invocation is one or more turns. A turn = one request/response cycle.

- A simple task (e.g., `config-auditor` scanning 10 files) may complete in 1-2 turns.
- A complex task (e.g., `architect` designing a failover strategy) may take 5-10 turns.
- Tool calls within a turn (file reads, grep, bash) count toward that turn's token total.

**Fleet multiplier:** A 10-agent sprint with 3 turns per agent = 30 turns minimum.

### Context Size

Every turn sends a context window to the model. The larger the context, the higher the token cost.

Context is composed of:

1. System instructions (~1-2K tokens per agent)
2. Task description and history (~2-5K tokens)
3. Files loaded during execution (~5-80K tokens depending on task)
4. Prior turn output carried forward (~2-10K tokens per turn)

**Key insight:** Context size compounds across turns. A 10K context in turn 1 may
grow to 40K by turn 4 as output is fed back in. This is where most UBB cost comes from.

### Model Tier

Higher-tier models cost more per token. See the [Model Optimization guide](model-optimization.md)
for the tier matrix.

Rough relative cost per million tokens:

| Tier | Example Model | Relative Cost |
|---|---|---|
| Premium | claude-opus-4.7 | 5.0x |
| Reasoning | claude-sonnet-4.6 | 1.0x (baseline) |
| Code | gpt-5.3-codex | ~1.0x |
| Fast | claude-haiku-4.5 | 0.1x |
| Fast | gpt-5.4-mini | 0.08x |

---

## Estimating Monthly UBB Cost from a Sprint Pattern

Use this formula to estimate monthly token consumption:

```text
Monthly tokens =
  sprints_per_month
  x agents_per_sprint
  x avg_turns_per_agent
  x avg_context_tokens_per_turn
  x (1 + output_ratio)
```

Where `output_ratio` is the fraction of input tokens that the model generates as output
(typically 0.2-0.4 for analysis tasks, 0.5-0.8 for code generation).

### Example: 4 sprints/month, 8 agents, Reasoning tier

```text
4 x 8 x 4 turns x 30,000 tokens/turn x 1.3
= 4 x 8 x 4 x 30,000 x 1.3
= 4,992,000 tokens ~= 5M tokens/month
```

At Reasoning-tier pricing, 5M tokens/month is the baseline reference. Premium-tier
agents at the same volume would cost ~5x more.

---

## Cost Controls

### Wave Sizing

Limit concurrent agents per wave to control burst token consumption and stay within
rate limits. Recommended maximums:

| Scenario | Max Concurrent Agents | Rationale |
|---|---|---|
| Standard sprint | 3 | Safe ceiling for most orgs; avoids 429s |
| Budget-sensitive sprint | 2 | Reduces peak token rate |
| Experimental / high-volume | 5 | Requires confirmed capacity; stagger by 15s |

Use the `sprint-kickoff-safe.ps1` script, which enforces a 15-second inter-agent
stagger and a wave cap of 3.

### Model Routing

Route tasks to the cheapest model that can complete them acceptably. Do not default
all agents to Premium.

```text
Scanning / auditing tasks   -> Fast tier (Haiku / gpt-5.4-mini)
Analysis / review tasks     -> Reasoning tier (Sonnet)
Code generation tasks       -> Code tier (Codex)
Architecture / security     -> Premium tier (Opus) -- use sparingly
```

See [model-optimization.md](model-optimization.md) for the full tier matrix and
override rules.

### Context Trimming

Reduce context size to cut token cost without sacrificing quality:

- **Summarize prior turns** with a Fast-tier model before feeding output into the next turn.
- **Load only required files** -- avoid whole-repo dumps; use targeted file lists.
- **Set explicit input budget limits** per agent role (see [token-optimization.md](token-optimization.md)).
- **Strip comments and whitespace** from code files when the agent only needs structure.

---

## Monitoring Token Consumption

### GitHub Billing Dashboard

1. Go to **GitHub.com -> Your Organization -> Settings -> Billing and plans**.
2. Select **Copilot** under Usage.
3. Filter by date range and view token consumption broken down by:
   - API vs. IDE usage
   - Model tier (if your plan exposes this)
   - Team or user (if team-level attribution is enabled)

### GitHub Audit Log

For programmatic access, query the audit log for `copilot.api_request` events.
This gives per-request token counts usable for cost attribution:

```bash
gh api /orgs/{org}/audit-log \
  --field phrase="action:copilot.api_request" \
  --field per_page=100 \
  --paginate
```

### Alert Thresholds Before Running Fleet Mode

Set budget alerts in the GitHub billing dashboard before running a large fleet sprint:

| Threshold | Action |
|---|---|
| 50% of monthly budget | Email alert -- review in-flight sprints |
| 75% of monthly budget | Downgrade all agents to Fast/Reasoning tier |
| 90% of monthly budget | Pause fleet dispatch; continue interactive-only |
| 100% of monthly budget | All Copilot API calls blocked until next billing cycle |

Configure alerts at: **Settings -> Billing -> Spending limits -> Set alert**.

---

## UBB vs. Per-Seat Decision Guide

Use this decision tree when evaluating billing model for your team's Copilot usage:

```text
Is all your Copilot usage interactive (IDE / chat)?
+-- Yes -> Per-seat is fine. No UBB exposure.
+-- No  -> Do you run automated agents / CI pipelines with Copilot API?
    +-- No  -> Per-seat is likely fine. Check included API quota.
    +-- Yes -> How many agent-turns per month?
        +-- < 10,000 turns/month -> Per-seat included quota may cover it.
        |   Confirm with GitHub account team.
        +-- >= 10,000 turns/month -> Plan for UBB.
            +-- Budget is fixed / sensitive -> Enforce wave caps + Fast tier default.
            +-- Budget is flexible         -> Use tier matrix; set alert thresholds.
```

**Rule of thumb:** If you run BaseCoat fleet sprints more than once a week with
more than 5 agents, budget for UBB and monitor consumption monthly.

---

## Adapting for Other Providers

This guide focuses on GitHub Copilot (GHCP). If your team routes agents to a
different provider, the billing unit and rate limits differ:

| Provider | Model tier equivalent | Rate limit difference | Billing unit |
|---|---|---|---|
| Azure OpenAI | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | TPM/RPM per deployment | Per token |
| Anthropic API | Opus ~= Premium, Sonnet ~= Standard, Haiku ~= Fast | Per-minute limits | Per token |
| AWS Bedrock | On-demand vs. provisioned | Regional quotas | Per token |
| OpenAI API | GPT-4o ~= Standard, GPT-4o-mini ~= Fast | Tier-based RPM/TPM | Per token |

For non-GHCP providers, replace the GitHub billing dashboard instructions with
the provider's cost management console and adjust rate-limit constants in
`sprint-kickoff-safe.ps1` to match the provider's documented limits.

---

## Related References

- [Model Optimization](model-optimization.md) -- Tier matrix, cost per model, override rules
- [Token Optimization](token-optimization.md) -- Context window management, budget allocation, compression
- [Rate Limit Guidance](rate-limit-guidance.md) -- Concurrency limits, retry strategy, wave patterns
- [Agent Tier Selection](agent-tier-selection.md) -- Matching agent roles to model tiers
- Issue [#720](https://github.com/IBuySpy-Shared/basecoat/issues/720) -- Tracking issue for UBB guidance
