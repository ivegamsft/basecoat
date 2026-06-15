# Program Bootstrap End-to-End Runbook

This runbook shows how to execute the `program-bootstrap` flow from planning to
startup-pack delivery.

## Preconditions

- Target repository exists and is accessible.
- Specialist agents used by program-bootstrap are available.
- Input goal and scope are approved.
- Preserve list for repo-specific delivery labels is defined.
- Execution model chosen (`child-sessions` recommended).

## Example invocation

```text
Use program-bootstrap with:
- program_name: "contoso-payments-modernization"
- target_repo: "org/contoso-payments"
- target_branch: "feat/program-bootstrap"
- mode: "dry-run"
- review_mode: true
- execution_model: "child-sessions"
- output_root: ".github/bootstrap/contoso-payments-modernization"
- preserve_labels: ["area/payments", "release/train-a", "wave:legacy-cutover"]
```

## Canonical output structure

All generated artifacts are grouped under one root directory in the target
repository:

```text
.github/bootstrap/<program_name>/
  summary/startup-summary.md
  checkpoints/bootstrap.json
  checkpoints/backlog-seed.json
  checkpoints/spec-pack.json
  checkpoints/architecture-pack.json
  checkpoints/workflow-schedule-pack.json
  checkpoints/governance-gate.json
  previews/dry-run-preview.json
  logs/<stage>.log
```

## Execution flow

1. Run in `dry-run` mode first.
2. Review generated preview writes and stage checkpoints.
3. Approve plan and rerun with `mode=apply`.
4. If a stage fails, resume from the last successful checkpoint using
   `resume_from_checkpoint`.

## Happy-path walkthrough

1. `bootstrap` completes with repo baseline artifacts.
2. `backlog-seed` produces issues and dependency map.
3. `spec-pack` links docs/spec artifacts to backlog items.
4. `architecture-pack` emits architecture and backend workflow specs.
5. `workflow-schedule-pack` emits rollout/schedule plan.
6. `governance-gate` normalizes governance labels while preserving
   repo-specific delivery labels.
7. Final startup summary links all generated artifacts.

## Failure and retry walkthrough

Scenario: `architecture-pack` fails due to missing non-functional requirements.

1. Program-bootstrap records a failed checkpoint for `architecture-pack`.
2. Update missing requirements in spec artifacts.
3. Re-run with:

```text
resume_from_checkpoint: "<checkpoint-id-from-architecture-pack>"
mode: "apply"
```

4. Program-bootstrap resumes at `architecture-pack` and skips completed prior
   stages.
5. Verify final summary includes resumed stage evidence and unchanged preserved
   labels report.

## Review-gated issue creation policy

- `review_mode=true`: issue creation and governance mutations stay in preview
  until explicit approval and apply rerun.
- `review_mode=false`: apply-mode can create issues immediately once backlog and
  governance contracts are satisfied.
- Recommended rollout: keep `review_mode=true` for initial adoption in a repo
  and flip to false only after one clean end-to-end run.

## Review checklist

- Startup summary artifact includes all stage outputs and links.
- Checkpoint IDs exist for every stage.
- Dry-run preview was reviewed before apply-mode writes.
- No repo-specific delivery label was deleted or renamed.
- Backlog/spec/architecture/workflow outputs are traceably connected.
