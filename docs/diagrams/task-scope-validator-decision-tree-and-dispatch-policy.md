# Task Scope Validator Decision Tree and Dispatch Policy

This diagram documents the pre-dispatch scope check used by the Task Scope
Validator agent.

- Source diagram: [task-scope-validator-decision-tree-and-dispatch-policy.excalidraw](task-scope-validator-decision-tree-and-dispatch-policy.excalidraw)
- Primary source terminology: `agents/basecoat-60-workflow-task-scope-validator.agent.md` and `skills/task-decomposition/automation-fitness-matrix.md`

## What it covers

1. Ordered checks for single issue, deterministic path, measurable success, and time bound.
2. Classification and confidence bands map to JSON output fields: `checks.*` drive classification; top-level `confidence`, `approved_for_dispatch`, and `recommended_agent` are the dispatch outputs.
   - `automatable` + `confidence >= 0.8` → `approved_for_dispatch: true`, `recommended_agent: task | general-purpose`
   - `gather-findings-only` + `confidence 0.6–0.79` → `approved_for_dispatch: true`, `recommended_agent: explore` (explore-only dispatch; `task` and `general-purpose` are not valid targets)
   - `defer` or `confidence < 0.6` → `approved_for_dispatch: false`, `recommended_agent: escalate`
3. Dispatch mapping from classification to agent choice: `task` or `general-purpose` (automatable), `explore` (gather-findings-only), or refinement/escalation (defer).
4. Remediation path when scope is too broad, success criteria are vague, or timing is unbounded.

## Intended operator usage

1. Run the validator before dispatching a sub-agent.
2. Route narrow, measurable work to `task` or `general-purpose`, evidence gathering to `explore`, and ambiguous work back for refinement.
3. Treat `defer` or confidence `< 0.6` as a prompt rewrite signal unless an explicit human override exists.
