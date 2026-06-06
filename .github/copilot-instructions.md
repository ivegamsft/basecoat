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
