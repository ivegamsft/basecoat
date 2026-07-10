---
description: "Enforces a mandatory sequential workflow for high-stakes changes. Prevents skipping phases when work involves architecture, public APIs, multi-agent dispatch, or new features with broad impact."
applyTo: "**/*"
---

# High-Stakes Workflow Chain

This instruction defines when the full sequential workflow chain is mandatory
(no Fast Path shortcut) and what constitutes gate approval at each phase.

## When Mandatory Chain Activates

The full workflow chain is required when the change involves ANY of:

- New feature with cross-cutting impact (touches 3+ modules or services)
- Architecture changes (new services, changed boundaries, data model restructuring)
- Public API changes (breaking changes, new endpoints, schema modifications)
- Multi-agent dispatch (work delegated to 2+ parallel agents)
- Security-sensitive changes (auth flows, encryption, access control)
- Infrastructure changes (IaC, networking, identity, DNS)
- Database migrations that alter existing columns or constraints

## When Fast Path Remains Available

Routine work can skip to Phase 2 (Plan) as defined in plan-first.instructions.md:

- Single-file bug fixes with clear reproduction
- Documentation or comment-only changes
- Configuration updates (env vars, feature flags)
- Dependency updates with no code changes
- Style or formatting fixes

## Mandatory Chain Phases

### Phase 1 — Brainstorm/Spec

- Identify the problem, constraints, and 2-3 possible approaches.
- Document trade-offs for each approach.
- Gate: User or reviewer approves the chosen approach before planning begins.

### Phase 2 — Plan

- Decompose into discrete tasks per the task granularity standard.
- Identify risks, dependencies, and rollback strategy.
- Gate: Plan reviewed and approved before implementation starts.

### Phase 3 — Execute

- Implement following the approved plan.
- Each task committed separately with clear messages.
- If diverging from plan, STOP and return to Phase 2 for re-approval.
- Gate: All tasks complete, tests pass, CI green.

### Phase 4 — Review

- Self-review against the original spec/brainstorm.
- Request human review for must-fix categorization.
- Address all feedback per the receiving-code-review protocol.
- Gate: Reviewer approves, no open must-fix items.

### Phase 5 — Finish

- Merge only after all prior gates are passed.
- Update documentation if behavior changed.
- Close related issues with references.

## Gate Approval Criteria

A gate is approved when:

- The human reviewer explicitly confirms (comment, approval, or thumbs-up).
- OR the automated check passes (CI green, no blocking lint, tests pass).
- Silence is NOT approval — explicit confirmation required for Phase 1 and Phase 2 gates.

## Integration

- Works with `plan-first.instructions.md` Phase 0 intent classification.
- If Phase 0 confidence >= 0.80 AND the change does NOT match mandatory criteria above, Fast Path is allowed.
- If the change matches mandatory criteria regardless of confidence score, the full chain applies.
- Human-in-the-loop skill provides the approval mechanism at each gate.
