---
description: "Use when deciding which agent tier to invoke for a task. Provides cost-aware, security-conscious agent routing to avoid mismatches between task requirements and agent capabilities."
applyTo: "agents/**/*,skills/**/*,prompts/**/*,.github/**/*"
---

# Agent-Tier Routing for Copilot Workflows

Route every task to the appropriate agent tier before dispatching. Tier selection affects
cost, latency, security posture, and session stability.

## Agent Tier Map

| Tier | Invocation | Scope | Best For |
|------|-----------|-------|----------|
| **Cloud Agent** | GitHub issue `/approve` | Async, repo-scoped | Long tasks, PR gates, compliance scans, irreversible ops |
| **CLI Fleet** | Background agents in session | Session-parallel | Fan-out of ≤5 independent subtasks, sprint execution |
| **CLI Main** | Main conversation | Interactive, high-reasoning | Planning, design debate, iterative debugging |
| **Local LLM** | Ollama / LM Studio | On-device, no egress | PII, secrets, regulated data, air-gapped environments |

## Enforced Rules (Non-Negotiable)

These rules override all other routing signals:

- **PII, secrets, or regulated data** → Local LLM only. No cloud egress permitted.
- **Irreversible operations** (force push, bulk delete, production deploy) → Cloud Agent only. A PR gate is required before execution.
- **Regulated or air-gapped environments** → Local LLM only. No external network calls.

## Routing Decision Matrix

Use the first matching row:

| Signal | Tier |
|--------|------|
| Security audit / compliance scan | Cloud Agent |
| Parallel independent subtasks (≤5) | CLI Fleet |
| Interactive design debate / planning | CLI Main |
| Long async task, no session dependency | Cloud Agent |
| High-frequency, low-stakes edits | Local LLM |
| Sprint execution with phase dependencies | CLI Fleet |
| PR review / code analysis | Cloud Agent |
| Iterative debugging with immediate feedback | CLI Main |

When multiple rows match, apply the enforced rules first, then prefer the tier with the
lowest cost that satisfies the latency and security requirements.

## Tier Capabilities and Constraints

### Cloud Agent (Copilot Coding Agent)

- Triggered by posting `/approve` on a GitHub issue (see repository conventions).
- Runs asynchronously; does not require an open session.
- Has access to the full repository via a checked-out workspace.
- PR gate is mandatory for irreversible operations — the agent opens a PR, a human merges.
- Not suitable for tasks that require back-and-forth interaction.

### CLI Fleet (Background Agents)

- Launched as parallel `task` sub-agents from the main conversation.
- Cap at **5 concurrent agents**. Exceeding this risks enterprise 429 rate limits.
- Each agent is stateless — provide complete context in the dispatch prompt.
- Use for workloads that decompose into independent, bounded subtasks.
- Coordinate phase dependencies in the main conversation; fleet agents do not coordinate with each other.

### CLI Main Conversation

- The primary interactive surface — high-reasoning, conversational, human-in-the-loop.
- Use for tasks that require judgment calls, ambiguity resolution, or iterative refinement.
- **Session timeout risk after ~15 minutes of inactivity** — do not use for long-running unattended tasks.
- Dispatches fleet agents and interprets their results; it is the orchestration layer.

### Local LLM (Ollama / LM Studio)

- Runs fully on-device with zero data egress.
- Mandatory for any input containing PII, credentials, or data governed by compliance policy.
- Lower reasoning capability than cloud models — scope tasks accordingly.
- No tool access beyond what the local runtime provides.

## Fleet Dispatch Patterns

### Pattern 1: Fan-out independent subtasks

```text
task(agent_type: "general-purpose", model: "gpt-5.3-codex",
     prompt: "Implement <bounded subtask A> in <file>. Context: ...")
task(agent_type: "general-purpose", model: "gpt-5.3-codex",
     prompt: "Implement <bounded subtask B> in <file>. Context: ...")
```

Dispatch all independent agents in **one turn** to avoid paying orchestration overhead
for each launch.

### Pattern 1A: `/fleet` sprint burndown for independent issues

Use `/fleet` when sprint items are independent and can be delivered in parallel.
Keep each work item scoped to a single issue, then reconcile conflicts in the main
conversation before opening or updating the PR.

```text
/fleet
Goal: Burn down sprint issues #1027, #1028, #1029, #1030 in one branch.
Agent 1: issue #1027 (/fleet usage docs)
Agent 2: issue #1028 (/every CI polling docs)
Agent 3: issue #1029 (/delegate mechanical PR docs)
Agent 4: issue #1030 (@-mention + /plan docs)
```

Use this pattern only when tasks do not depend on each other and can be validated
independently.

### Pattern 2: Phase-gated sprint

```text
Phase 1 → dispatch fleet agents for independent tasks
Phase 2 → collect results in CLI Main, resolve conflicts
Phase 3 → dispatch Cloud Agent via /approve for final PR merge
```

### Pattern 3: Escalate to Cloud Agent after local draft

```text
1. Draft and iterate with CLI Main or Local LLM
2. Push branch
3. Post /approve on tracking issue → Cloud Agent opens or updates PR
```

## Prompt and Command Guidance for Fast Routing

### `@`-mention files to preload context

When asking for debugging or workflow help, mention the exact files up front. This
reduces exploration turns and improves first-pass accuracy.

```text
Debug workflow failures in @.github/workflows/project-rules-drift-audit.yml
and @scripts/validate-basecoat.ps1. Focus on failed status checks only.
```

### `/plan` gate for multi-issue sprints

For broad requests (for example, "burn down these 4 issues"), run `/plan` first to
produce a scoped, approvable execution plan before dispatching agents or editing files.

```text
/plan implement issues #1027, #1028, #1029, #1030 in one docs PR
```

### `/every` polling for CI monitoring

Use `/every` to automate workflow status checks instead of manual "did CI finish?"
prompts. Keep polling intervals at 2 minutes or higher to reduce API churn.

```text
/every 2m check whether adoption-metrics workflow succeeded on this branch
```

### `/delegate` for mechanical PR creation

Use `/delegate` when work is straightforward and primarily mechanical (for example,
doc regeneration, low-risk single-file updates, or scripted updates requiring routine
branch/commit/push/PR steps).

Prefer local workflow when live debugging or iterative design decisions are required.
Prefer `/delegate` when the value is in automation and avoiding multi-account
auth-switching during PR creation.

## Anti-Patterns

| Anti-Pattern | Risk | Fix |
|---|---|---|
| Dispatch 7+ fleet agents simultaneously | Enterprise 429 rate limit | Cap fan-out at 5; batch remaining work |
| Send PII or proprietary code to cloud agents | Data egress violation | Route to Local LLM |
| Use CLI Main for tasks > 15 minutes | Session timeout loses progress | Delegate to Cloud Agent or CLI Fleet |
| Use Cloud Agent for interactive back-and-forth | Agent cannot respond in real time | Use CLI Main |
| Omit PR gate for irreversible operations | Unreviewed destructive change | Always require PR for force push / bulk delete / deploy |

## Related Routing Guidance

- [Model Routing](model-routing.instructions.md) — which LLM tier (Opus / Sonnet / Haiku) within a chosen agent
- [Runner Routing](../docs/reference/guardrails/runner-routing.md) — which CI runner for GitHub Actions jobs
- [Context Routing](references/token-economics/context-routing.md) — which context tiers to load before dispatching
