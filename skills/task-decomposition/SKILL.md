---
name: task-decomposition
compatibility: [github-copilot-cli]
description: "Use when breaking complex tasks into sub-agent-friendly chunks, validating automation fitness, and composing multi-step prompts. USE FOR: split large tasks into smaller async work items, decide if work is automatable vs research vs deferred, validate sub-agent prompts for clarity, design task decomposition workflows. DO NOT USE FOR: single-step code changes, immediate sync problem-solving, architectural design starting from scratch."
---
# Task Decomposition Skill

Guide for breaking complex tasks into automation-friendly chunks and validating sub-agent prompts.

## When to Use

Apply this skill when:

- You have a large, multi-faceted request that would benefit from parallel async execution
- You need to decide which sub-agents can handle which pieces autonomously
- You're writing prompts for sub-agents and want to ensure clarity and context completeness
- You need to distinguish research tasks from automatable work from deferred decisions

## Guardrails

- **Avoid over-decomposition:** if a task naturally fits one agent in <5 minutes, don't split it unnecessarily
- **Include context boundaries:** each sub-prompt must be self-contained; don't force tasks to depend on each other unless they genuinely must
- **Prefer parallelism:** design tasks so multiple agents can work concurrently
- **Validate completeness:** each decomposed task should have a clear success criteria and artifact ownership

## Templates in This Skill

| Template | Purpose |
|---|---|
| `complex-task-breakdown-template.md` | How to split one large task into N focused sub-tasks |
| `automation-fitness-matrix.md` | Decision tree for categorizing work as automatable, research, or deferred |
| `prompt-validation-checklist.md` | Criteria for validating sub-agent prompts before dispatch |

## Examples

See `examples/` folder for good vs bad task framing with side-by-side comparisons.

## Agent Pairing

Use with specialized agents (`backend-dev`, `frontend-dev`, `code-review`, etc.) as the primary execution path. Pair with planning agents when the decomposition strategy itself is the blocker.
