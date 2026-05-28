---
description: "Use when dispatching sub-agents or choosing models for tasks. Provides cost-aware model routing to avoid over-spending on premium models for simple tasks."
applyTo: "**/*"
---

# Model Routing for Copilot CLI Fleet Mode

Route tasks to the cheapest model that can handle them reliably.

## Model Tier Map

| Tier | Models | Cost | Best For |
|------|--------|------|----------|
| **Premium** | Claude Opus 4.7, Opus 4.7 High, Opus 4.7 XHigh, Opus 4.6 | $$$ | Complex reasoning, multi-step planning, security audits, ambiguous requirements |
| **Standard** | Claude Sonnet 4.6, Sonnet 4.5, GPT-5.4, GPT-5.2 | $$ | Multi-file implementation, refactoring, code review, prose docs |
| **Code** | GPT-5.3-Codex, GPT-5.2-Codex | $$ | Code generation, debugging, migration scripts, protocol implementation |
| **Fast/Cheap** | Claude Haiku 4.5, GPT-5.4 mini, GPT-5 mini, GPT-4.1 | $ | Single-file edits, git ops, simple lookups, triage, binary checks |

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

### Use Code (GPT-5.3-Codex / GPT-5.2-Codex) for

- Pure code generation tasks (APIs, components, scripts)
- Debugging and root-cause analysis in code
- Database schema design and migration scripts
- Protocol implementation (MCP, REST, gRPC)

### Use Fast/Cheap (Haiku) for

- Single-file documentation
- README updates
- Git operations (merge, push, branch)
- Simple file creation from a template
- Boilerplate code generation
- Polling or monitoring tasks

## Fleet Mode Dispatch Patterns

### Pattern 1: Override model for simple tasks

```
task(agent_type: "general-purpose", model: "claude-haiku-4.5", ...)
```

Use when the task is straightforward and doesn't need Sonnet-level reasoning.

### Pattern 2: Batch git operations into one task agent

Instead of running 4 `gh pr merge` commands from the main (Opus) conversation:

```
task(agent_type: "task", prompt: "Merge PRs #267, #268, #273, #274 with --squash --delete-branch")
```

This costs 1 Haiku request instead of 4 Opus requests.

### Pattern 3: Pre-read files before dispatching

Reading files in the main conversation (Opus) costs premium tokens. Instead:

- Use explore agents (`claude-haiku-4.5` or `gpt-5.4-mini`) for research
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
| Using general-purpose for doc creation | Sonnet for a README update | Use `model: "claude-haiku-4.5"` |
| Using Sonnet for pure code tasks | Code-optimized model underused | Use `model: "gpt-5.3-codex"` for implementation |
