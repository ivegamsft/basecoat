---
description: "GitHub Actions workflows, infrastructure automation, PRD/spec gates, and authentication"
applyTo: ".github/workflows/**/*,iac/**/*"
---

# Deployment & Infrastructure

## Authentication

- Write operations (push, merge) require the `ibuyspy` account
- Always run `gh auth switch --user ibuyspy` before push/merge operations
- The `ivegamsft` account has read-only access and will get 403 on write attempts

## PRD / Spec Gate

The `prd-spec-gate.yml` workflow blocks PRs with:
- ≥ 500 line churn **OR** ≥ 12 files that lack PRD and spec links
- PRs touching risky paths (skills/, agents/, instructions/) get advisory warning below threshold
- Add the `skip-prd-spec-check` label to bypass

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
