# AI SDLC Operating Model

## Purpose

This document defines the canonical operating model for AI-enabled software delivery
in BaseCoat and consuming repositories.

## Two Complementary Planes

BaseCoat uses a two-plane model:

1. **Guardrails plane (BaseCoat)** — Governs how work is performed.
2. **Visibility plane (GitHub Projects + repo operations)** — Tracks what work is happening and its status.

Both planes are required. Guardrails without visibility creates blind execution.
Visibility without guardrails creates inconsistent execution.

## Plane 1: Guardrails (BaseCoat)

BaseCoat provides the execution contract through four primitives:

- **Agents** — role-specific workflows and execution logic
- **Skills** — reusable procedures, templates, and decision aids
- **Instructions** — ambient standards, safety, and quality policies
- **Prompts** — structured entry points for repeatable tasks

Guardrails outcomes:

- Consistent quality and policy compliance across sessions
- Reusable patterns instead of ad hoc prompts
- Safer automation with scoped instructions and validation

## Plane 2: Visibility (GitHub Operating Surface)

Visibility is provided by GitHub-native artifacts:

- **Issues** for scoped work items
- **Pull requests** for reviewed change units
- **Workflow runs** for operational evidence and enforcement
- **Milestones / Projects** for sprint and portfolio tracking

Visibility outcomes:

- Execution state is observable and auditable
- Blockers and carryover are explicit
- Planning and delivery telemetry are available for retrospectives

## Operating Rule

Use both planes in every sprint:

1. Define work in issues and milestones (visibility).
2. Execute with BaseCoat agents/skills/instructions/prompts (guardrails).
3. Merge only when required checks are green (guardrails + visibility gate).
4. Capture evidence in PRs/issues/workflow runs (visibility).

## Practical Mapping

| Delivery need | Guardrails plane | Visibility plane |
|---|---|---|
| Build a feature | Agent + paired skills + instructions | Issue + PR + checks |
| Enforce standards | Instructions + validation workflows | Status checks + run logs |
| Coordinate sprint execution | Prompt/agent routing patterns | Milestones + project board |
| Close out and handoff | DoD-style execution checks | Carryover issues + summary links |

## Related References

- [reference/goals.md](goals.md)
- [reference/product.md](product.md)
- [../philosophy.md](../philosophy.md)
- [operations/operational-runbook.md](../operations/operational-runbook.md)
