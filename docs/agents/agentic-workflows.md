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

### 2. Add the Repository Secret

Agentic workflows require a fine-grained Personal Access Token to authenticate
the Copilot agent:

1. Go to [Create a fine-grained PAT](https://github.com/settings/personal-access-tokens/new)
2. Set **Resource owner** to your user account (not the org)
3. Under **Account permissions**, set **Copilot Requests** → `Read`
4. No repository permissions needed
5. Set PAT expiration to **30 days or less** and generate the token
6. Add to the repository: **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `COPILOT_GITHUB_TOKEN`
   - Value: the token you generated

## Model Compatibility Guardrail

Some repositories or enterprise tenants do not expose every Copilot model. If a
run fails with `400 The requested model is not supported`, set a supported model
in the workflow lock file fallback (for example `gpt-5-mini`) and/or configure a
repository variable override:

- `GH_AW_MODEL_AGENT_COPILOT`
- `GH_AW_MODEL_DETECTION_COPILOT`

Prefer explicit `gpt-5-mini` defaults for portability unless a workflow requires
a different model tier.

## Active Workflows

| Workflow | Trigger | What It Does |
|---|---|---|
| [`issue-triage.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/.github/workflows/issue-triage.md) | Issue opened | Classifies issue, applies priority labels, posts triage summary |
| [`retro-facilitator.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/.github/workflows/retro-facilitator.lock.yml) | Weekly schedule | Analyzes past week's activity, creates sprint retrospective issue |
| [`self-healing-ci.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/.github/workflows/self-healing-ci.lock.yml) | Workflow run failed | Fetches failed job logs, posts root-cause diagnosis |
| [`release-impact-advisor.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/.github/workflows/release-impact-advisor.lock.yml) | PR opened | Assesses blast radius, rollback complexity, and risks |
| [`code-review-agent.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/.github/workflows/code-review-agent.lock.yml) | PR opened / synchronized | Reviews diff for bugs, security issues, and logic errors |

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

To reduce this risk in BaseCoat, the compiled issue-triage workflow defaults both
agent and detection phases to `gpt-5-mini` when no repository variable override
is set.

If you need an override, use repository variables (not prompt text):

- `GH_AW_MODEL_AGENT_COPILOT`
- `GH_AW_MODEL_DETECTION_COPILOT`

Set each variable to a model confirmed as supported by your Copilot plan/tier.
Unsupported values fail fast during `Execute GitHub Copilot CLI`.

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
- [gh-aw reference](https://github.github.com/gh-aw/reference/)
- Issue #560 — parent tracking issue for this feature
