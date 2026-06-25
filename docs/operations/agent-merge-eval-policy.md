# Agent Merge Eval Validation Policy

## Overview

The `agent-merge.yml` workflow enforces eval companion validation as a **required PR
status check**. Any PR that modifies agent or skill assets must pass this check before
merge is permitted.

## Required Status Check Name

Branch protection rules must include the following exact status check name:

```text
Agent merge guardrails / Validate eval companions
```

> **Note:** GitHub Actions job and step names are joined with ` / ` to form the
> required status check identifier. The job is `guardrails` (display name
> `Agent merge guardrails`) and the step display name is `Validate eval companions`.

## What Is Validated

The eval companion step in `agent-merge.yml` enforces:

1. Every `agents/*.agent.md` file must have a matching `agents/*.agent.eval.yaml`
   companion.
2. Every `skills/*/SKILL.md` file must have a matching `skills/*/eval.yaml`
   companion.

Missing eval companions cause the step — and therefore the required status check — to
fail, blocking merge.

## Configuring Branch Protection

To wire this into your repository's branch protection policy:

1. Navigate to **Settings → Branches → Branch protection rules** for the `main`
   branch.
2. Enable **Require status checks to pass before merging**.
3. Add the following required status check:

   ```text
   Agent merge guardrails / Validate eval companions
   ```

4. Optionally also require the full job:

   ```text
   Agent merge guardrails
   ```

5. Enable **Require branches to be up to date before merging** to prevent stale
   bypasses.

## Bypass Labels (Not Recommended)

There is intentionally no skip/bypass label for eval companion validation. Missing
eval companions indicate incomplete work and must be resolved before merge.

## Regression Test

See `tests/agent-merge-eval-policy-tests.ps1` for automated coverage of the policy
wiring expectations.

## Generating Agent Eval Stubs

When adding new agent files, use `scripts/generate-agent-eval-stubs.ps1` to create the
required `*.agent.eval.yaml` companion files automatically.

### Usage

```powershell
# Preview what would be generated (no files written)
pwsh scripts/generate-agent-eval-stubs.ps1 -DryRun

# Generate missing stubs for all agents
pwsh scripts/generate-agent-eval-stubs.ps1

# Regenerate stubs even if they already exist
pwsh scripts/generate-agent-eval-stubs.ps1 -Force

# Target a specific agents directory (absolute or repo-relative path)
pwsh scripts/generate-agent-eval-stubs.ps1 -AgentsDir agents -DryRun
```

### File Naming Convention

The script derives the eval companion filename from the full agent filename stem:

| Agent file | Generated eval companion |
|---|---|
| `agents/basecoat-10-core-sprint-retrospective.agent.md` | `agents/basecoat-10-core-sprint-retrospective.agent.eval.yaml` |
| `agents/basecoat-50-my-new-agent.agent.md` | `agents/basecoat-50-my-new-agent.agent.eval.yaml` |

> **Important:** The companion must use the full filename stem — including the numeric
> prefix and tier prefix — not a shortened logical name. The CI guardrail matches on the
> full stem.

### Stub Content

Generated stubs include:

- `name`: `<full-stem>-routing` (used by the eval harness to identify the routing test)
- `skill`: path to the agent `.md` file
- `description`: derived from the agent's frontmatter `name:` field
- Four scenarios: two positive (`expect_activation: true`) and two negative
  (`expect_activation: false`)

Edit the generated stub to add realistic input examples before merging.

### Test Coverage

See `tests/generate-agent-eval-stubs-tests.ps1` for automated tests verifying correct
filename generation, YAML content, DryRun/Force modes, and guardrail simulation.
