# Program Bootstrap Stage Contracts

This document defines the stage I/O contracts used by
`agents/program-bootstrap.agent.md`.

## Contract goals

- Keep orchestration thin and specialist-driven.
- Ensure deterministic handoffs between stages.
- Enable dry-run previews and resumable execution.
- Protect repo-specific delivery labels during governance normalization.

## Global contract envelope

All stages must emit this minimum envelope:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `stage` | string | Yes | Stage identifier |
| `status` | string | Yes | `completed`, `failed`, or `blocked` |
| `inputs` | object | Yes | Stage-scoped inputs consumed |
| `outputs` | object | Yes | Stage outputs and artifact links |
| `evidence` | object | Yes | Commands, files, and validation notes |
| `checkpoint_id` | string | Yes | Resume token persisted after stage exit |
| `execution_model` | string | Yes | `child-sessions` (default) or `single-session` |
| `blockers` | string[] | Conditional | Required when `status` is not `completed` |

## Stage contracts

| Stage | Primary delegate(s) | Required inputs | Required outputs | Exit gate |
| --- | --- | --- | --- | --- |
| `bootstrap` | `project-onboarding` | repo target, base branch, setup scope | bootstrap summary, prerequisite status, scaffold diffs | repo bootstrap is complete or clearly blocked |
| `backlog-seed` | `sprint-planner` | goal, constraints, review-mode flag | issue drafts or created issue IDs, dependency map, ordering rationale | actionable backlog items generated with traceability |
| `spec-pack` | `tech-writer`, `product-manager` | backlog outputs, scope, acceptance expectations | spec links, doc links, acceptance matrix | all required spec artifacts linked in summary |
| `architecture-pack` | `solution-architect`, `backend-dev` | specs, constraints, non-functional requirements | architecture docs, backend workflow specs, implementation boundaries | architecture artifacts are internally consistent |
| `workflow-schedule-pack` | workflow specialists | architecture outputs, rollout constraints | workflow plan, schedule map, governance checkpoints | automation plan is ready for review or apply |
| `governance-gate` | coordinator + governance checks | proposed label mutations, preserve list | normalized governance labels, preserved delivery labels report | no repo-specific delivery label removed or renamed |

## Session model contract

- Default: `execution_model=child-sessions`.
- Allowed override: `execution_model=single-session` for lightweight scopes.
- Every checkpoint must persist `execution_model` and `stage_attempt` to keep
  resume deterministic after retries.

## Output directory contract

Canonical root:
`.github/bootstrap/<program_name>`.

Required artifacts:

| Path | Required | Purpose |
| --- | --- | --- |
| `summary/startup-summary.md` | Yes | Single linked startup-pack summary |
| `checkpoints/<stage>.json` | Yes | Stage envelope and resume token |
| `previews/dry-run-preview.json` | Yes in dry-run | Proposed writes with no side effects |
| `logs/<stage>.log` | Yes | Stage evidence, retries, and blockers |

## Dry-run contract

When `mode=dry-run`, every stage must:

- report intended writes under `outputs.preview_writes`
- skip side effects (issue creation, label mutation, PR creation)
- still emit checkpoints so reviewers can inspect planned execution

## Resume contract

Resume behavior is checkpoint-based:

1. load `resume_from_checkpoint`
2. verify prior stage outputs are present
3. continue from the next incomplete stage
4. do not re-run completed stages unless explicitly requested

## Review-mode contract

When `review_mode=true` and `mode=apply`:

- backlog issue creation is staged and not executed until approval
- governance mutations are staged as `attempted_mutations`
- final summary must include explicit approval points before apply actions

## Label safety contract

Governance normalization is restricted:

- allowed: standardizing governance labels (for example priority or governance)
- disallowed: deleting or renaming repo-specific delivery labels
- required: report `preserved_labels` and `attempted_mutations` in final summary

## Final startup summary contract

The final artifact must include:

1. stage status matrix with checkpoint IDs
2. links to generated issues/docs/specs/workflow outputs
3. dry-run preview details or apply-mode mutation log
4. preserved repo-specific delivery label evidence
5. execution model and output root used for the run
