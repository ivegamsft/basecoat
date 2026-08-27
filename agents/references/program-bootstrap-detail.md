# Program Bootstrap — Detail Reference

## Checkpointing and Resume

After every stage, write checkpoint state with:

- stage name
- status (`completed|failed|blocked`)
- output links
- blocker summary (if present)

When `resume_from_checkpoint` is provided, continue from the next incomplete
stage only.

## Dry-run Behavior

In `dry-run` mode:

- Execute planning and validation logic without side effects.
- Do not create or mutate issues/labels/PRs.
- Emit proposed writes as a preview artifact.

## Failure Handling

- Retry transient failures once.
- For deterministic failures, stop stage, persist checkpoint, and surface
  blocker evidence.
- Never continue to downstream stages when an upstream contract is unmet.
