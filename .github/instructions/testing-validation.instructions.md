---
description: "Repository validation, testing commands, and CI expectations"
applyTo: "scripts/**/*,tests/**/*,.github/workflows/**/*"
---

# Testing & Validation

## Local Validation

- Structure validation: `pwsh scripts/validate-basecoat.ps1`
- Full test suite: `pwsh tests/run-tests.ps1`
- Markdown lint: `pwsh tests/run-tests.ps1` (included in full suite)
- Docs build: `python -m mkdocs build --strict`

## CI Workflows

After any workflow or deployment change:

1. Trigger the workflow: `gh workflow run <workflow.yml>`
2. Monitor until green: `gh run watch`
3. Mark work complete only after verified success

## E2E Verification Gate

If a change affects runtime behavior, UX flows, auth, or integration boundaries,
do not claim success without targeted E2E validation (for example, Playwright in
consumer repos).

**See also:** [E2E Validation Lifecycle diagrams](../../docs/diagrams/e2e-validation-lifecycle.md)
for visual reference of the gate funnel, pass/fail outcomes, and test scope mapping.

Required preconditions before running E2E:

1. Lint, build, and typecheck complete successfully.
2. Auth-mode prerequisites are set (for example, `E2E_AUTH_BYPASS` when used).
3. The application base URL is reachable and backing dependencies are running
   (for example, Docker or local DB services).

## Common Test Failures

`instructions/basecoat-20-lang-governance.instructions.md` frequently breaks lint after rebases because
upstream changes introduce pre-existing violations. Always run `pwsh tests/run-tests.ps1`
after rebasing. Common errors to fix:

- **MD031/MD040**: code fences need blank lines before/after and a language specifier
- **MD032**: lists must be surrounded by blank lines
- **MD026**: headings must not end with a trailing colon or period

## Evaluation Coverage

- All agents require `<agent>.agent.eval.yaml` companion file
- All skills require `eval.yaml` in skill directory
- Tests fail if coverage is missing
