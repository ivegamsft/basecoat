# Copilot Session Cost Estimation Guide

## Estimation Workflow

1. **Collect dispatch data** — enumerate all tool calls and sub-agent dispatches in the session,
   noting the model identifier used for each.
2. **Estimate token consumption** — use message length and interaction count as a proxy for
   input/output tokens per dispatch.
3. **Apply cost rates** — map each model to its published token rate to produce a per-dispatch
   and per-session cost estimate.
4. **Identify high-cost dispatches** — rank dispatches by estimated cost and flag any where a
   lighter model would suffice.
5. **Generate routing recommendations** — for each flagged dispatch, recommend an alternative
   model tier and explain the trade-off.
6. **Produce session summary** — fill in the session cost estimate template with totals,
   per-model breakdown, and optimization actions.

## Guardrails

- Token estimates are proxies, not exact counts — present them with an explicit uncertainty range.
- Do not use model cost rates that are more than 30 days old; rates change and stale data misleads decisions.
- ROI reports must include the number of issues resolved, not just cost; cost alone is not an actionable metric.
- Do not make routing recommendations that sacrifice correctness for cost on security or compliance tasks.

## Agent Pairing

- **agentops agent** (`agents/basecoat-10-core-agentops.agent.md`) — monitors agent lifecycle health and can
  incorporate cost signals into rollback and routing decisions.
- **performance-analyst agent** (`agents/basecoat-10-core-performance-analyst.agent.md`) — pairs token-cost data
  with latency and throughput metrics for a full efficiency picture.
- **sprint-planner agent** (`agents/basecoat-10-core-sprint-planner.agent.md`) — uses ROI estimates to prioritize
  automation investments.
