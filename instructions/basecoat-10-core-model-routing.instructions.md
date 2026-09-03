---
description: "Use when dispatching sub-agents or choosing models for tasks. Provides cost-aware model routing to avoid over-spending on premium models for simple tasks."
applyTo: "agents/**/*,skills/**/*,prompts/**/*,.github/**/*"
---

# Model Routing for Copilot CLI Fleet Mode

Route tasks to the cheapest model that can handle them reliably. Use
[`docs/reference/model-capabilities.md`](../docs/reference/model-capabilities.md)
as the generated source of truth for supported models and capabilities.

## Model Tier Map

| Tier | Models | Cost | Best For |
|------|--------|------|----------|
| **Premium** | Claude Opus family, GPT-5.4+ reasoning models | $$$ | Complex reasoning, multi-step planning, security audits, ambiguous requirements |
| **Standard** | Claude Sonnet family, GPT-5.4 | $$ | Multi-file implementation, refactoring, code review, prose docs |
| **Code** | GPT-5.3-Codex | $$ | Code generation, debugging, migration scripts, protocol implementation |
| **Fast/Cheap** | GPT-5.4 mini, GPT-5 mini, MAI-Code-1-Flash | $ | Single-file edits, git ops, simple lookups, triage, binary checks |

## Task-to-Model Assignment

### Use Premium (Opus) only for

- Sprint planning and prioritization
- Architectural decisions with tradeoffs
- Reviewing complex PRs (security, cross-cutting changes)
- Orchestrating multi-agent workflows (the main conversation)

### Use Standard (Sonnet / GPT-5.4) for

- Multi-file code implementation
- Test suite creation
- Refactoring across modules
- Complex documentation with cross-references

### Use Code (GPT-5.3-Codex) for

- Pure code generation tasks (APIs, components, scripts)
- Debugging and root-cause analysis in code
- Database schema design and migration scripts
- Protocol implementation (MCP, REST, gRPC)

### Use Fast/Cheap for

- Single-file documentation
- README updates
- Git operations (merge, push, branch)
- Simple file creation from a template
- Boilerplate code generation
- Polling or monitoring tasks

## Fleet Mode Dispatch Patterns

### Pattern 1: Override model for simple tasks

```text
task(agent_type: "general-purpose", model: "gpt-5.4-mini", ...)
```

Use when the task is straightforward and doesn't need Sonnet-level reasoning.

### Pattern 2: Batch git operations into one task agent

Instead of running 4 `gh pr merge` commands from the main (Opus) conversation:

```text
task(agent_type: "task", prompt: "Merge PRs #267, #268, #273, #274 with --squash --delete-branch")
```

This costs one fast-model request instead of four premium-model requests.

### Pattern 3: Pre-read files before dispatching

Reading files in the main conversation (Opus) costs premium tokens. Instead:

- Use explore agents (`gpt-5.4-mini` or another evaluated fast model) for research
- Include key file content directly in sub-agent prompts
- Let the sub-agent (Sonnet) do its own reading

### Pattern 4: Reduce orchestration turns

Each back-and-forth in the main conversation is an Opus request. Minimize by:

- Dispatching all independent agents in one turn
- Batching `gh` commands with `&&` or `;`
- Using `task` agents for multi-step shell workflows

## Cost Impact Example

A typical sprint session (11 issues, ~90 min):

| Approach | Opus Requests | Estimated Cost |
|----------|---------------|----------------|
| All in main conversation | ~200 | $8.00 |
| Fleet mode (current) | ~50 | $2.00 |
| Fleet mode + model routing | ~25 | $1.00 |

## Anti-Patterns

| Anti-Pattern | Why It's Expensive | Fix |
|-------------|-------------------|-----|
| Polling for PRs from main conversation | Each poll = 1 Opus request | Dispatch a task agent to poll |
| Reading agent results then re-summarizing | Double-processing at Opus cost | Trust sub-agent summaries |
| Running `gh pr merge` inline | Simple command wastes Opus | Batch into task agent |
| Using general-purpose for doc creation | Sonnet for a README update | Use `model: "gpt-5.4-mini"` |
| Using Sonnet for pure code tasks | Code-optimized model underused | Use `model: "gpt-5.3-codex"` for implementation |

## Reasoning-Effort Safety

- `reasoning_depth` is a task-routing hint, not a provider request parameter.
- Emit `reasoning_effort` only after `Test-ModelReasoningEffort` confirms compatibility
  using the authenticated runtime's supported-effort list.
- For fixed-effort models such as Claude Haiku 4.5 and GPT-5.4 mini, omit
  `reasoning_effort`; never default it to `medium`.
- Public support, Auto-selection eligibility, and effective account entitlement
  are separate signals. Verify entitlement through the authenticated Copilot
  runtime before dispatch.
