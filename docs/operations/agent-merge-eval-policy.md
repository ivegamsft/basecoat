# Agent Merge Eval Validation Policy

## Overview

The `agent-merge.yml` workflow enforces eval companion validation as a **required PR
status check**. Any PR that modifies agent or skill assets must pass this check before
merge is permitted.

## Required Status Check Name

Branch protection rules must include the following exact status check name:

```
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

   ```
   Agent merge guardrails / Validate eval companions
   ```

4. Optionally also require the full job:

   ```
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
