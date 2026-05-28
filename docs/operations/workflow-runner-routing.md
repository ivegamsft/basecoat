# Workflow Runner Routing Baseline

This repository uses explicit runner routing for deployment workflows that can benefit from org runner pools:

- `.github/workflows/mcp-build.yml`
- `.github/workflows/mcp-deploy.yml`
- `.github/workflows/extension-deploy.yml`
- `.github/workflows/portal-deploy.yml`

Each uses:

```yaml
runs-on: ${{ vars.RUNNER_DEPLOY || 'ubuntu-latest' }}
```

This keeps a safe GitHub-hosted fallback when `RUNNER_DEPLOY` is not configured.

## Intentionally GitHub-hosted workflows

The following remain on GitHub-hosted runners by design:

- `validate-basecoat.yml`, `ci.yml`, and `pr-validation.yml` for fast, deterministic PR feedback.
- `docs.yml` for standard public tooling (MkDocs + GitHub Pages) with no private network requirement.
- `publish-to-production.yml` and `release.yml` for short-lived GitHub API and repository sync operations.
- Matrix jobs pinned to platform images (for example, `windows-latest` in `validate-basecoat.yml` and OS matrix jobs in `smoke-test.yml` and `sync-test.yml`) to preserve cross-platform coverage.
