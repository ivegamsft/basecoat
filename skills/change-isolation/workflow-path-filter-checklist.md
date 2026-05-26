# Workflow Path Filter Checklist

Use this checklist when reviewing workflow changes for isolation correctness.

## Trigger Scope

- [ ] Workflow has `paths` filters for owned layer paths.
- [ ] Workflow does not include unrelated layer paths.
- [ ] `pull_request` and `push` triggers use consistent scope intent.
- [ ] Shared path triggers are explicit and justified in comments.
- [ ] `workflow_dispatch` is reserved for manual promotion and not used as a coupling workaround.

## Job Guards

- [ ] Deploy jobs are gated from PR events when production deployment is not intended.
- [ ] PR builds avoid pushing publish artifacts unless explicitly required.
- [ ] Fork PR behavior is safe (`if` guards for secrets and privileged steps).
- [ ] Matrix jobs are layer-scoped and avoid global fan-out.

## Cross-Layer Safety

- [ ] No job references another layer's working directory unless declared dependency exists.
- [ ] No blanket `on: push` across `main` without path filters for layer-specific workflows.
- [ ] `workflow_run` triggers cannot recursively fan out into unrelated lanes.
- [ ] Concurrency groups are lane-specific to prevent unrelated cancellation.

## Release Independence

- [ ] Versioning tags are lane-scoped where independent release cadence exists.
- [ ] Rollback procedure is lane-local.
- [ ] Promotion gates are lane-local unless change is in a shared contract path.

## Verification

- [ ] A trigger matrix test proves only expected workflows run for representative layer-only changes.
- [ ] Guardrail tests fail if scope broadens beyond declared lane boundaries.
