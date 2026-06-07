# Ephemeral Workflow Convention

An ephemeral workflow is a GitHub Actions workflow that runs exactly once, archives
its output, and then disables or removes itself. This distinguishes it from recurring
workflows driven by `schedule` (cron) or `push` triggers.

## What is an ephemeral workflow?

Ephemeral workflows are designed for tasks that must happen once and only once.
After the workflow completes its main job it self-destructs — either by disabling
itself via the GitHub API or by opening a PR to delete the workflow file. The key
properties are:

- **Single execution**: the workflow has no recurring trigger
- **Archived output**: results are stored as a GitHub Actions artifact before cleanup
- **Self-disabling**: a cleanup job prevents accidental re-runs

## When to use

Use an ephemeral workflow for:

- **One-time bootstrap** — initial overlay setup, schema migration, data seed
- **Audit snapshots** — point-in-time compliance reports
- **Onboarding automation** — runs once per new repository
- **Migration scripts** — tasks that must never run twice

Do not use an ephemeral workflow for tasks that might legitimately need to re-run.
Use a regular workflow with an `if:` guard instead.

## The pattern

An ephemeral workflow has three parts:

1. **Trigger** — `workflow_dispatch` with a `confirm` input that must equal `"yes"`.
   This safety gate prevents accidental runs from the Actions UI or API.
2. **Main job** — performs the one-time action and uploads results as an artifact.
3. **Cleanup job** — runs after the main job (`if: always()`) and disables the
   workflow via the GitHub CLI, or opens a PR to delete the file.

### Cleanup step

```yaml
- name: Disable this workflow after run
  run: gh workflow disable "${{ github.workflow }}" --repo "${{ github.repository }}"
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Naming convention

Prefix the filename with `once-` to make the intent clear at a glance:

- `once-bootstrap-overlay.yml`
- `once-migrate-schema.yml`
- `once-audit-snapshot.yml`

## Template

```yaml
name: once-<action-name>

on:
  workflow_dispatch:
    inputs:
      confirm:
        description: 'Type "yes" to confirm this one-time run'
        required: true
        default: ""

jobs:
  main:
    name: Run one-time action
    runs-on: ubuntu-latest
    if: ${{ github.event.inputs.confirm == 'yes' }}
    steps:
      - uses: actions/checkout@v4

      # ── YOUR ONE-TIME STEPS GO HERE ──────────────────────────────────────
      - name: Perform one-time action
        run: |
          echo "Running one-time action…"
          # add your commands here
      # ─────────────────────────────────────────────────────────────────────

      - name: Archive output
        uses: actions/upload-artifact@v4
        with:
          name: once-action-output
          path: output/          # adjust to match your output directory
          retention-days: 90

  cleanup:
    name: Disable workflow
    needs: main
    runs-on: ubuntu-latest
    if: always()
    permissions:
      actions: write
    steps:
      - name: Disable this workflow after run
        run: gh workflow disable "${{ github.workflow }}" --repo "${{ github.repository }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Anti-patterns

Avoid the following when working with ephemeral workflows:

- **Do not use `schedule` (cron)** — cron triggers will keep firing, defeating
  the single-run guarantee
- **Do not leave disabled workflows in the repo indefinitely** — delete the file
  after confirming success, either manually or via an automated PR in the cleanup job
- **Do not skip the `confirm` gate** — without it, a click in the Actions UI or
  an accidental API call can re-trigger the workflow
- **Do not use for re-runnable tasks** — if there is any chance the operation
  needs to be repeated, use a regular workflow with an `if:` condition instead

## Related

- [`docs/reference/guardrails/runner-routing.md`](../reference/guardrails/runner-routing.md) — CI runner selection
- [`instructions/basecoat-60-workflow-workflow-integrity.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/basecoat-60-workflow-workflow-integrity.instructions.md) — workflow integrity rules
