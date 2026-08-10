# Agentic Workflows

BaseCoat uses [GitHub Agentic Workflows](https://copilot-academy.github.io/workshops/copilot-customization/agentic_workflows)
(`gh aw`) to automate repository operations with Copilot. Agentic workflows are
Markdown files compiled to GitHub Actions YAML, running AI agents in response
to GitHub events.

## Prerequisites

### 1. Install the CLI Extension

```bash
gh extension install github/gh-aw
```

### 2. Configure Copilot Authentication

BaseCoat's checked-in agentic workflows use the recommended organization-backed
authentication contract:

```yaml
permissions:
  copilot-requests: write
```

This uses the short-lived `${{ github.token }}` for inference and avoids
personal access token expiration. The organization must have an active Copilot
subscription with centralized billing.

For a repository without organization-backed Copilot billing, remove that
permission before compiling and configure a fine-grained
`COPILOT_GITHUB_TOKEN` with **Copilot Requests: Read** instead.

## Model Compatibility Guardrail

Some repositories or enterprise tenants do not expose every Copilot model. If a
run fails with `400 The requested model is not supported`, select a supported
model in the checked-in workflow source and recompile the lock file. BaseCoat
pins models statically so source, generated locks, and contract tests remain
consistent; do not edit generated lock files or add repository-variable
overrides. Prefer `gpt-5-mini` for portability unless a workflow requires a
different model tier.

## Active Workflows

| Workflow | Trigger | What It Does |
|---|---|---|
| [`issue-triage.md`](../../.github/workflows/issue-triage.md) | Issue opened | Classifies issue, applies priority labels, posts triage summary |
| [`retro-facilitator.md`](../../.github/workflows/retro-facilitator.md) | Weekly schedule | Analyzes past week's activity, creates sprint retrospective issue |
| [`self-healing-ci.md`](../../.github/workflows/self-healing-ci.md) | Workflow run failed | Fetches failed job logs, posts root-cause diagnosis |
| [`release-impact-advisor.md`](../../.github/workflows/release-impact-advisor.md) | PR opened | Assesses blast radius, rollback complexity, and risks |
| [`code-review-agent.md`](../../.github/workflows/code-review-agent.md) | PR opened / synchronized | Reviews diff for bugs, security issues, and logic errors |

## Workflow Authoring

Each workflow has two files that must be committed together:

```text
.github/workflows/
  issue-triage.md          ← human-editable source (Markdown + YAML frontmatter)
  issue-triage.lock.yml    ← compiled GitHub Actions YAML (do not edit)
```

### Edit a Workflow

1. Edit the `.md` file (frontmatter or body)
2. If frontmatter changed, recompile: `gh aw compile issue-triage`
3. Commit both `.md` and `.lock.yml`

> **Tip:** Markdown body edits (the natural language instructions) don't require
> recompilation. Only frontmatter changes (triggers, permissions, safe-outputs)
> need a recompile.

### Create a New Workflow

```bash
gh aw new my-workflow          # Creates .github/workflows/my-workflow.md
# Edit the .md file
gh aw compile my-workflow      # Generates my-workflow.lock.yml
git add .github/workflows/my-workflow.md .github/workflows/my-workflow.lock.yml
git commit -m "feat: add my-workflow agentic workflow"
```

### Compile All Workflows

```bash
gh aw compile
```

## Security Model

Agentic workflows use a defense-in-depth model:

1. **Agent job** runs with read-only permissions
2. **Write operations** are buffered as artifacts
3. **Threat detection job** analyzes artifacts for secret leaks and policy violations
4. **Safe output jobs** execute writes with minimal scoped permissions — only after detection passes

Never add write permissions directly in the `permissions:` block. All writes
must go through `safe-outputs:`.

## Model Compatibility Guardrails

Issue triage failures can present as:

```text
400 The requested model is not supported.
```

To reduce this risk in BaseCoat, the issue-triage source statically pins both
agent and detection phases to `gpt-5-mini`. Repository model variables do not
override this workflow. Change the source `model:` value, recompile the lock,
and run the workflow contract tests when a model migration is required.

## Allowed Expressions

The `gh aw` compiler enforces a strict allowlist of `${{ }}` expressions for
security. Key allowed values:

- `github.event.issue.number`, `github.event.issue.title`
- `github.event.pull_request.number`, `github.event.pull_request.title`
- `github.event.workflow_run.id`, `github.event.workflow_run.conclusion`
- `github.repository`, `github.run_number`, `github.actor`

For disallowed fields (e.g., `issue.body`, `workflow_run.name`), instruct the
agent to fetch data using `gh` CLI commands in the workflow body.

## Reference

- [Agentic Workflows Workshop](https://copilot-academy.github.io/workshops/copilot-customization/agentic_workflows)
- [gh-aw reference](https://github.com/github/gh-aw)
- Issue #560 — parent tracking issue for this feature
