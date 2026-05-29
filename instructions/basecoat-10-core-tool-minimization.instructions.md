---
description: "Use when configuring agent tool access or planning task execution. Enforces selective tool enablement, lower context noise, and disciplined MCP server usage."
applyTo: "**/*"
---

# Tool Minimization

Use this instruction when deciding which tools an agent should have enabled for a task, workflow, or session.

## Principle

- Only enable tools the agent actually needs for the current task.
- Every enabled tool increases system prompt size, which adds tokens and can slow reasoning.
- Unused tools create choice paralysis and increase the chance that the agent picks a suboptimal path.

## Tool Audit Checklist

Before starting a task, assess which tool categories are actually required:

- **File operations** — read, write, or search? Enable only the needed file tools such as `grep`, `glob`, `view`, and `edit`.
- **Execution** — build, test, or run commands? Enable `bash` or `powershell` only when execution is necessary.
- **Git** — commit, branch, diff, or push? Enable Git access only for workflows that need repository history or publishing.
- **External access** — API calls, package lookups, or web retrieval? Enable `curl` or `web_fetch` only when outside information is required.
- **Specialized systems** — database, deployment, browser automation, or cloud tools? Enable them only when the task directly depends on them.

## Selective Enablement Patterns

### Read-only Tasks

Use for code review, repository exploration, or documentation inspection.

- Enable read and search tools.
- Disable write tools.
- Disable execution tools unless validation is explicitly required.

### Writing Tasks

Use for implementation, refactoring, or content creation.

- Enable targeted edit tools.
- Enable execution tools needed for validation.
- Avoid unrelated external or deployment tools unless the task needs them.

### Research Tasks

Use for investigation, comparison, or external fact gathering.

- Enable search tools and web access.
- Disable local execution if no build or test step is needed.
- Keep write access off unless capturing results is part of the task.

### Deployment Tasks

Use for release, provisioning, or production changes.

- Enable the full tool stack required for the workflow.
- Keep destructive capabilities behind explicit confirmation gates.
- Remove local-only or exploratory tools that do not help the deployment.

## Context Budget Impact

| Tools Enabled | Approx. Token Cost | Use When |
|---|---|---|
| Minimal (5-6) | ~2K tokens | Focused single-purpose tasks |
| Standard (10-12) | ~5K tokens | General development |
| Full (20+) | ~10K+ tokens | Complex multi-domain tasks |

Treat tool availability as part of context budgeting. Expanding tool access should be a deliberate tradeoff, not a default.

## MCP Server Management

- Only connect MCP servers needed for the current workflow.
- Disconnect idle servers so they do not keep consuming context budget.
- Use lazy initialization: connect on first use instead of at session start.
- Prefer a small allowlist of active servers rather than a broad always-on catalog.
- Reassess active servers when the task changes materially.

## Anti-Patterns

- Enabling all tools just in case.
- Leaving database tools active during pure code review.
- Connecting deployment tools during local development.
- Keeping web search enabled for offline or air-gapped work.
- Preserving stale MCP connections after the workflow no longer needs them.

## Review Lens

- Does the agent have only the tools required for the current step?
- Are expensive or specialized tools disabled until they are actually needed?
- Would removing unused tools reduce prompt size without blocking execution?
- Are MCP servers connected lazily and disconnected when idle?
- Has tool scope been revisited after a task or phase change?
