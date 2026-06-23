# Workflow Runner Routing Baseline

This repository uses explicit capability-based routing for workflow jobs so runner
selection is deterministic rather than ad hoc.

## Routing classes

Canonical runner classes live in:

- `.github/workflow-runner-capability-classes.json`

| Runner class | Default runs-on | Use for |
|---|---|---|
| `github-hosted-linux` | `ubuntu-latest` | lint, unit tests, docs, repo validation |
| `github-hosted-windows` | `windows-latest` | Windows-specific validation |
| `github-hosted-macos` | `macos-latest` | macOS-specific validation |
| `self-hosted-linux` | self-hosted group + labels | deploy/release jobs requiring private network or managed identity |
| `configurable-deploy` | `${{ vars.RUNNER_DEPLOY \|\| 'ubuntu-latest' }}` | deploy-path migration with a safe fallback |
| `github-hosted-matrix` | `${{ matrix.os }}` | multi-OS validation where a single job fans out across OS images |
| `reusable-workflow` | `uses: ./.github/workflows/<reusable>.yml` | delegated runner choice managed by a reusable workflow |

## Capability audit

Every workflow job is classified by required capability via:

```powershell
pwsh scripts/audit-workflow-runner-capabilities.ps1 -OutputFormat markdown -OutputPath docs/operations/workflow-runner-capability-audit.md
```

The audit report includes:

1. Classification of every workflow job.
2. Recommended runner class versus actual runner assignment.
3. Logged mismatches and conditional routes.

The scheduled automation lives at:

- `.github/workflows/workflow-runner-capability-audit.yml`

## Deployment workflows

Deploy workflows can route through org pools with safe fallback:

```yaml
runs-on: ${{ vars.RUNNER_DEPLOY || 'ubuntu-latest' }}
```

This pattern is currently used by deployment-oriented workflows and remains
compatible with protected self-hosted rollouts.

## Intentionally GitHub-hosted workflows

The following remain on GitHub-hosted runners by design:

- `validate-basecoat.yml`, `ci.yml`, and `pr-validation.yml` for fast, deterministic PR feedback.
- `docs.yml` for standard public tooling (MkDocs + GitHub Pages) with no private network requirement.
- Matrix jobs pinned to platform images (for example, `windows-latest` in `validate-basecoat.yml` and OS matrix jobs in `smoke-test.yml` and `sync-test.yml`) to preserve cross-platform coverage.
