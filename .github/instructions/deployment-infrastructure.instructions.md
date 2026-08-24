---
description: "GitHub Actions workflows, infrastructure automation, PRD/spec gates, and authentication"
applyTo: ".github/workflows/**/*,iac/**/*"
---

# Deployment & Infrastructure

## Authentication

- Write operations (push, merge) require the `ibuyspy` account
- Always run `gh auth switch --user ibuyspy` before push/merge operations
- The `ivegamsft` account has read-only access and will get 403 on write attempts

## Pre-Release Token Preflight

Before pushing a release tag, validate `PRODUCTION_REPO_TOKEN` readiness to prevent
partial-release state (internal release created, production mirror stale).

Run the preflight check:

```bash
gh workflow run token-preflight.yml --repo IBuySpy-Shared/basecoat
gh run watch
```

A green run confirms the token is configured, can read `ivegamsft/basecoat`, and has
push permissions. Only proceed with tagging after a passing run.

If the preflight fails, follow the remediation steps in the error output to rotate the
token before tagging. The `publish-to-production.yml` workflow enforces this gate
automatically at runtime via a `preflight-token-check` job that must pass before
the `publish` job runs.

**Setup or troubleshooting?** See the comprehensive guide:

- `docs/guides/PRODUCTION_TOKEN_SETUP.md` — Complete token generation & troubleshooting
- Issue #575 — Original setup guidance (closed, regex applied)
- Issue #1352 — Current blocker tracking token permission fix

## Release Audit Token

`.github/workflows/release.yml` includes an "Audit reusable workflow sharing"
step that confirms this repo's Actions are org-shared before a tag is allowed
to publish. `.github/workflows/package-basecoat.yml`'s `release` job runs the
same audit, but only when triggered by a tag push (`if: startsWith(github.ref,
'refs/tags/')`) — a plain `workflow_dispatch` packaging run skips it entirely.
Both authenticate with `BASECOAT_RELEASE_AUDIT_TOKEN` (falling back to
`PRODUCTION_REPO_TOKEN` if unset) and require `Administration: read` on
`IBuySpy-Shared/basecoat` itself — a different scope than `PRODUCTION_REPO_TOKEN`, which only covers
the `ivegamsft/basecoat` mirror. Do not rely on the fallback: set
`BASECOAT_RELEASE_AUDIT_TOKEN` explicitly, or the step 404s and hard-fails
the release (see Issue #2837 and `docs/operations/github-secrets.md`).

`pwsh scripts/bootstrap.ps1` surfaces this requirement automatically whenever
`.github/workflows/release.yml` or `.github/workflows/package-basecoat.yml`
is present.

## PRD / Spec Gate

The `prd-spec-gate.yml` workflow blocks PRs with:

- ≥ 500 line churn **AND** ≥ 12 files that lack PRD and spec links
- PRs touching risky paths (`skills/`, `agents/`, `instructions/`, `scripts/`, `.github/workflows/`) get advisory warning below threshold
- Add the `skip-prd-spec-check` label to bypass
- Merge queue (`merge_group`) checks pass when no pull request payload exists
- Bot/agent-authored PRs (`ibuyspy` or GitHub Bot accounts) bypass the gate

Contributor guideline: Keep PRs within 15 files or fewer and 300 changed lines or fewer
unless the PR is a justified mechanical change.

## Adoption Metrics Dashboard

Deployed to GitHub Pages: <https://ibuyspy-shared.github.io/basecoat/>

Architecture: MkDocs force-pushes to `gh-pages` (wiping all content). The
`adoption-metrics.yml` workflow then auto-repopulates metrics via a `workflow_run`
trigger that fires after every successful docs deploy. Do NOT attempt to preserve files
across `mkdocs gh-deploy --force` — the workflow_run pattern handles recovery.

## MCP Server — Adoption Metrics

An MCP server at `mcp/basecoat-metrics/` exposes the metrics data to AI agents.

Build: `cd mcp/basecoat-metrics && npm install && npm run build`

VS Code config (`.vscode/mcp.json`):

```json
{
  "servers": {
    "basecoat-metrics": {
      "type": "stdio",
      "command": "node",
      "args": ["${workspaceFolder}/mcp/basecoat-metrics/dist/index.js"]
    }
  }
}
```

Tools: `get-latest-metrics`, `get-history`, `get-alerts`, `get-repo-metrics`
