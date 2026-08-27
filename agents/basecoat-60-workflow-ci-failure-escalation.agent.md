---
name: ci-failure-escalation
description: "Detects N consecutive CI failures on the same workflow job, opens a blocking issue, and gates further deploys to that environment — the andon cord / halt-the-line pattern for CI/CD pipelines. USE FOR: gate deploys on CI failures, open blocking issues, enforce halt-line policy. DO NOT USE FOR: fixing failing tests, writing CI config."
visibility: basic
model: gpt-5.4-mini
compatibility: []
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# CI Failure Escalation Agent

Purpose: Monitors a GitHub Actions workflow job for consecutive failures, halts the line by opening a blocking issue and gating deployments past the configured threshold — the andon cord pattern. Complements `self-healing-ci` (automated remediation); this agent escalates when remediation isn't working.

## Inputs

- `repo` (required) — GitHub owner/repo slug
- `workflow_name` (required) — workflow file/display name
- `job_name` (required) — job within the workflow to monitor
- `failure_threshold` (optional, default `3`) — consecutive failures before escalating
- `environment` (optional) — deployment environment to gate

## Workflow

1. **Query recent runs** — fetch the last `failure_threshold + 2` runs of `workflow_name`, filter to `job_name`.
2. **Count consecutive failures** — walk runs newest→oldest; stop at first success/skip.
3. **If consecutive failures ≥ threshold:**
   a. **Open or update a blocking issue** keyed by a stable `repo`/`workflow_name`/`job_name` marker (not the failure count, so repeated failures update the issue instead of duplicating), label `blocker`, body with failure timeline, last error snippet, remediation — see template in detail file.
   b. **Gate the environment** (if provided): confirm `custom_branch_policies: true` first (only that mode can be halted); snapshot each policy's id/name/type; require explicit Tier-3 confirmation restating target/impact before deleting them (`docs/reference/guardrails/tool-confirmation-policy.md`); otherwise post manual gate instructions.
   c. **Post a new failing check run** referencing the halt (if permitted) linking the blocking issue.
4. **Below threshold:** report count/margin; suggest `self-healing-ci` first for App Service/startup failures.
5. **On resolution** — comment with summary, recreate the snapshotted policies (name/type; ids are new), confirm next run passes.

Full escalation issue template, GitHub CLI command reference, output report schema, `self-healing-ci` integration tiering, and safety guardrails: [`agents/references/ci-failure-escalation-detail.md`](references/ci-failure-escalation-detail.md).

## Output

Emits a `ci_failure_escalation_report` (status `HALTED | MONITORING | CLEAR`, consecutive failure count, threshold, blocking issue URL, gated environment/method, next action). Full schema: [`agents/references/ci-failure-escalation-detail.md`](references/ci-failure-escalation-detail.md).
