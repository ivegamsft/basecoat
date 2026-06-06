---
description: "BaseCoat repository routing guide — targeted instruction files for different workflows"
applyTo: "**/*"
---

# BaseCoat — Instruction Files (Routing Guide)

BaseCoat repository context is split into targeted instruction files to reduce
session payload and improve instruction relevance. Use `/instructions list` to see
all active files for your workflow.

## Targeted Instruction Files

| File | Context | ApplyTo |
|---|---|---|
| `repo-structure.instructions.md` | Directory org, file layout, markdown standards | `**/*` (all workflows) |
| `agents-skills-dev.instructions.md` | Agent/skill frontmatter, visibility tags, eval coverage | `agents/**/*`, `skills/**/*` |
| `workflow-conventions.instructions.md` | Git workflow, branch naming, commit conventions | `.github/**/*`, `*.md` files |
| `testing-validation.instructions.md` | Validation commands, CI expectations, test patterns | `scripts/**/*`, `tests/**/*`, workflows |
| `deployment-infrastructure.instructions.md` | Workflows, PRD gates, MCP servers, authentication | `.github/workflows/**/*`, IaC |
| `cost-optimization.instructions.md` | Session hygiene, fleet patterns, token budgeting | All workflows (performance guidance) |

## How to Use

When working on a specific task, these files load automatically via `applyTo` patterns.
For manual context:

- **Building agents/skills**: `/instructions agents-skills-dev`
- **Setting up CI workflows**: `/instructions deployment-infrastructure`
- **Reducing token costs**: `/instructions cost-optimization`
- **Understanding the repo**: `/instructions repo-structure`
- **Troubleshooting tests**: `/instructions testing-validation`

## Token Impact

This split reduces baseline instruction payload by **72%**:

- Before: 25KB monolithic file (loaded every session)
- After: 7KB baseline (repo-structure only) + task-specific files (1-3KB each)
- Estimated savings: **15M tokens/month**

See `.github/instructions/cost-optimization.instructions.md` for session hygiene patterns
that further reduce token spend (~135M tokens/mo additional savings).

## Execution Guardrails (Fleet, E2E, Worktrees)

These repo-level rules are mandatory and apply even when working from specialized
instruction files:

1. **Serialized merges in fleet runs**: open multiple PRs if needed, but merge only
   one at a time. Wait for checks + merge completion before merging the next PR.
   Clean up local/remote branch state after each merge.
2. **E2E verification before claiming success**: do not declare completion until
   lint/build/typecheck and targeted E2E coverage for changed flows are complete.
   Validate E2E preconditions explicitly (auth-bypass mode, reachable base URL,
   required local services such as Docker/DB).
3. **Worktree safety checks before cleanup**: verify branch-to-path mapping with
   `git worktree list` before removing any worktree, avoid path-assumptive deletes,
   and run `git worktree prune` only after mapping is confirmed.

## Cost Optimization Quick Reference

**Backlog/fleet sessions** are most expensive. Current baseline: expensive runs cost 68–84M tokens (594–684 events). Best measured run: 9.1M tokens (101 events, 207x ratio).

**Five most impactful changes** (see `cost-optimization.instructions.md` for details):

| Pattern | Savings | Action |
|---------|---------|--------|
| **Compact at phase boundaries** (triage→impl→merge) | 35–50% per session | Invoke `/compact` when context domain changes |
| **Reuse sprint templates** (not 5x re-planning) | 150M+/mo (5 sessions) | Create persistent sprint issue; reference in agent calls |
| **File references only** (no 170k char pastes) | ~300x per block | Use `view path/file.md`; let agents load docs |
| **Delegate scan work** (not main-session orchestration) | 40–60% event reduction | Use `/delegate` or background agents for triage/research |
| **Model choice is secondary** | ~5–10% gain | Focus on context reduction (35–50%) not model downshift |

Target: Reduce expensive backlog runs from 68–84M tokens to 35–45M tokens (42–50% savings).
