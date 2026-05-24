---
description: "BaseCoat repository context and conventions for GitHub Copilot"
applyTo: "**/*"
---

# BaseCoat — Copilot Repository Context

BaseCoat is an enterprise shared library of GitHub Copilot customization assets
including agents, skills, instruction files, prompt templates, and documentation.

## Repository Conventions

- **Agents**: Flat files at `agents/<name>.agent.md` with YAML frontmatter (name, description)
- **Instructions**: Files at `instructions/<name>.instructions.md` with frontmatter (description, applyTo)
- **Skills**: Directories at `skills/<name>/` containing SKILL.md with frontmatter
- **Prompts**: Files at `prompts/<name>.prompt.md` with YAML frontmatter
- **Docs**: Markdown files in `docs/` — no frontmatter required

## Markdown Standards

- Use `##` headings, never bold-as-heading (MD036)
- Blank lines before/after code fences (MD031)
- Files end with single newline (MD047)
- No trailing spaces, consistent list markers
- No emojis in any content (code, docs, UI, commit messages)

## Branch and Commit Conventions

- Branches: `<type>/<issue-number>-<short-description>`
- Commits: `<type>(<scope>): <summary>` (conventional commits)
- Always include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer

## Testing

- Structure validation: `pwsh scripts/validate-basecoat.ps1`
- Full test suite: `pwsh tests/run-tests.ps1`
- After any workflow or deployment change, trigger the workflow and confirm success
  before marking work complete (e.g., `gh workflow run docs.yml` then `gh run watch`)

## Authentication

- Write operations (push, merge) require the `ibuyspy` account
- Always run `gh auth switch --user ibuyspy` before push/merge operations
- The `ivegamsft` account has read-only access and will get 403 on write attempts

## PR Workflow

Standard pattern for all changes:

```bash
git checkout -b <type>/<issue>-<desc>
git add . && git commit -m "<type>(<scope>): <summary>"
gh auth switch --user ibuyspy
git push origin <branch>
gh pr create --title "<title>" --body "<body>"
gh pr merge --squash --admin
```

Use `--admin` to bypass CI wait when change is pre-validated locally.

## Triggering the Copilot Coding Agent

Post `/approve` as an issue comment to trigger the Copilot coding agent workflow
(`issue-approve.yml`). This adds `approved` + `copilot-agent` labels and assigns
the issue to Copilot. The `@copilot` mention does **not** trigger the agent.

## Markdown Lint — Recurring Failure Patterns

`instructions/governance.instructions.md` frequently breaks lint after rebases because
upstream changes introduce pre-existing violations. Always run `pwsh tests/run-tests.ps1`
after rebasing. Common errors to fix:

- **MD031/MD040**: code fences need blank lines before/after and a language specifier
- **MD032**: lists must be surrounded by blank lines
- **MD026**: headings must not end with a trailing colon or period

## Adoption Metrics Dashboard

Deployed to GitHub Pages: <https://ibuyspy-shared.github.io/basecoat/>

Architecture: MkDocs force-pushes to `gh-pages` (wiping all content). The
`adoption-metrics.yml` workflow then auto-repopulates metrics via a `workflow_run`
trigger that fires after every successful docs deploy. Metrics live at
`dashboard/metrics/` on `gh-pages`. Do NOT attempt to preserve files across
`mkdocs gh-deploy --force` — the workflow_run pattern handles recovery.

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

## PRD / Spec Gate

The `prd-spec-gate.yml` workflow blocks PRs with ≥ 500 line churn or ≥ 12 files
that lack PRD and spec links. PRs that only touch risky paths (skills/, agents/,
instructions/, etc.) below the size threshold get an advisory warning only. Add
the `skip-prd-spec-check` label to bypass.

Batch PRs should stay within the contributor guideline of 15 files or fewer and
300 changed lines or fewer unless the PR is a justified mechanical change.
