# Complex Task Breakdown Template

Use this template to decompose a large, multi-faceted task into smaller, parallel work items for concurrent agent execution.

## 1. Original Task Statement

**Title:** [Insert task title]

**Full Description:** 
[Paste or describe the complete task as received. Include all acceptance criteria, constraints, and known dependencies.]

**Estimated Complexity:** [Low | Medium | High | Very High]

---

## 2. Task Analysis

### Core Objectives (What must be done)
- [ ] Objective 1
- [ ] Objective 2
- [ ] Objective 3

### Hard Constraints (Non-negotiable)
- Constraint 1
- Constraint 2
- Constraint 3

### Known Dependencies
- Dependency on [X] (must complete before starting this task)
- Dependency on [Y] (blocks downstream task Z)

---

## 3. Decomposition Matrix

For each sub-task, assess:
- **Time Estimate:** how long should this reasonably take one agent?
- **Agent Type:** which agent (or skill) best fits this work?
- **Blocker:** does this depend on another sub-task completing first?
- **Output Artifact:** what concrete deliverable confirms success?

| Sub-Task | Time Est. | Agent/Skill | Blocker? | Success Criteria |
|---|---|---|---|---|
| 1. [Sub-task A] | 15 min | backend-dev | None | [Artifact or test passing] |
| 2. [Sub-task B] | 30 min | frontend-dev | After A | [Artifact or test passing] |
| 3. [Sub-task C] | 20 min | code-review | None (parallel) | [Artifact or test passing] |

---

## 4. Parallelization Strategy

### Can Run Concurrently
- Sub-task A and C (no dependencies between them)

### Sequential Dependencies
- B must wait for A (identified in blocker column above)

### Total Estimated Time
- **Sequential path:** A → B = 15 + 30 = 45 min
- **Parallel optimization:** (A, C in parallel) + B = max(15, 20) + 30 = 50 min
  - *Note:* marginal speedup; consider running all three for simplicity if time permits

---

## 5. Sub-Agent Prompt Framing

For each sub-task, provide a focused prompt snippet ready to copy into a sub-agent call:

### Sub-Task A Prompt
```
[Self-contained prompt for sub-agent A. Include:
- What specifically to build/fix/review
- Input files or context needed
- Success criteria
- Any constraints]
```

### Sub-Task B Prompt
```
[Self-contained prompt for sub-agent B, with note if it depends on output from A]
```

### Sub-Task C Prompt
```
[Self-contained prompt for sub-agent C]
```

---

## 6. Rollup & Integration

### How Results Combine
Describe how the outputs of each sub-task come together:
- Sub-task A produces [artifact], which feeds into [integration step]
- Sub-task B produces [artifact], verified by [test/review]
- Sub-task C produces [artifact], integrated via [merge/deployment/etc]

### Final Acceptance Criteria
- [ ] All sub-tasks completed
- [ ] Integration test or smoke test passes
- [ ] No regressions in dependent systems

---

## 7. Fallback & Escalation

If a sub-task becomes blocked or fails:
- **Escalation path:** [Who to notify or which agent to escalate to]
- **Rollback plan:** [How to undo partial progress if needed]
- **Recovery steps:** [If sub-task X fails, re-attempt with Y approach or defer to Z]

---

## Notes

[Any additional context, references, or notes for the decomposer or agents]
