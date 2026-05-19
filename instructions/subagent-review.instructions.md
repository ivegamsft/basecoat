---
description: "Defines a two-stage review protocol for subagent task output. Stage 1 checks spec compliance, Stage 2 checks code quality. Applies when orchestrating multi-agent work."
applyTo: "**/*"
---

# Two-Stage Subagent Review Protocol

When an orchestrator dispatches work to subagents, each task output must pass
two sequential review stages before acceptance. This prevents spec drift from
compounding across parallel tasks.

## Stage 1 — Spec Compliance

Does the output match what was requested?

### Pass Criteria

- [ ] All acceptance criteria from the task description are met.
- [ ] Output stays within the declared scope (no unasked-for changes).
- [ ] File paths match those specified in the plan.
- [ ] No new dependencies or tools introduced without plan approval.
- [ ] The behavior described in the task is demonstrably implemented.

### Fail Actions

If Stage 1 fails:

1. Document which acceptance criteria are unmet.
2. Re-dispatch the task with specific feedback (not "try again").
3. Include the failing criteria and what the output is missing.
4. A task may be re-dispatched at most twice for Stage 1 failures.

After two Stage 1 failures, escalate to human review or re-plan the task
(it may be under-specified or infeasible as written).

## Stage 2 — Code Quality

Is the implementation well-crafted?

Stage 2 only runs after Stage 1 passes. A spec-compliant but poorly-written
output is easier to fix than a well-written output that solves the wrong problem.

### Pass Criteria

- [ ] Code is correct (handles edge cases, no obvious bugs).
- [ ] Tests are present and meaningful (not trivially passing).
- [ ] Project conventions followed (naming, structure, patterns).
- [ ] No dead code, commented-out blocks, or debugging artifacts.
- [ ] Error handling is explicit, not swallowed silently.
- [ ] Changes are minimal — no scope creep beyond the task.

### Fail Actions

If Stage 2 fails:

1. Provide specific line-level feedback on what needs improvement.
2. Re-dispatch with the quality feedback attached.
3. A task may be re-dispatched once for Stage 2 failures.

After one Stage 2 failure and re-dispatch, accept the best version and file
a follow-up task for the remaining quality issues.

## Integration with Orchestrator

When the orchestrator collects subagent results:

1. Run Stage 1 on each result independently.
2. Resolve any cross-task conflicts (duplicate changes, contradictions).
3. Run Stage 2 on each Stage-1-passed result.
4. Only integrate results that pass both stages.

## Failure Escalation

| Scenario | Action |
|----------|--------|
| Stage 1 fails once | Re-dispatch with feedback |
| Stage 1 fails twice | Escalate to human or re-plan |
| Stage 2 fails once | Re-dispatch with quality feedback |
| Stage 2 fails after re-dispatch | Accept best version, file follow-up |
| Multiple tasks fail Stage 1 | The plan may be under-specified — pause and re-plan |
