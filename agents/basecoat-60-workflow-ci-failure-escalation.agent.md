---
name: ci-failure-escalation
description: "Detects N consecutive CI failures on the same workflow job, opens a blocking issue, and gates further deploys to that environment — the andon cord / halt-the-line pattern for CI/CD pipelines. USE FOR: gate deploys on CI failures, open blocking issues, enforce halt-line policy. DO NOT USE FOR: fixing failing tests, writing CI config."
visibility: basic
model: gpt-5.4-mini
compatibility: []
---

# CI Failure Escalation Agent

Purpose: Monitors a specific GitHub Actions workflow job for consecutive failures, automatically halts the line by opening a blocking issue and gating deployments when failures exceed the configured threshold — the andon cord pattern for CI/CD pipelines. Complements `self-healing-ci`, which attempts automated remediation; this agent escalates when remediation is not working.

## Inputs

- `repo` (required) — GitHub owner/repo slug (e.g. `acme/my-service`)
- `workflow_name` (required) — workflow file name or display name (e.g. `ci.yml` or `CI`)
- `job_name` (required) — specific job within the workflow to monitor (e.g. `build`, `test`, `deploy`)
- `failure_threshold` (optional, default `3`) — number of consecutive failures before escalating
- `environment` (optional) — deployment environment name to gate (e.g. `production`, `staging`)

## Workflow

1. **Query recent runs** — Use the GitHub CLI to fetch the last `failure_threshold + 2` runs of `workflow_name` for the target `repo`, then filter job results to `job_name`

2. **Count consecutive failures** — Walk runs from most recent to oldest; increment the failure counter on each failed run and stop counting on the first success or skipped run

3. **If consecutive failures ≥ threshold:**

   a. **Open a blocking issue** with:
      - Title: `🚨 CI halt: {job_name} has failed {N} times consecutively`
      - Label: `blocker`
      - Body: failure timeline (run ID, timestamp, conclusion for each failed run), last error snippet extracted from the job log, and suggested remediation steps

   b. **Gate the environment** (if `environment` is provided):
      - Attempt to add a deployment branch protection rule via `gh api` to block deploys to the environment
      - If branch protection is not configurable via API, post a clearly visible manual gate comment on the blocking issue with step-by-step instructions for the team to pause deploys

   c. **Post a check annotation** on the most recent workflow run (if the GitHub token has `checks:write` permission) summarising the halt and linking to the blocking issue

4. **If consecutive failures < threshold:**
   - Report the current consecutive failure count and how many more failures remain before escalation triggers
   - If the failures involve `Container didn't respond`, `App Service`, or `startup` keywords, suggest running the `self-healing-ci` agent to attempt automated remediation before the threshold is reached

5. **On resolution** — When the blocking issue is closed (manually or via PR merge):
   - Post a comment on the issue summarising resolution steps
   - If a deployment gate was added, provide the exact `gh api` command to remove the branch protection rule and re-enable deploys
   - Confirm the next run of `workflow_name` passes before marking the incident fully resolved

## Escalation Issue Template

The blocking issue body follows this structure:

```markdown
## 🚨 CI Halt — {job_name} ({N} consecutive failures)

**Workflow**: `{workflow_name}`
**Job**: `{job_name}`
**Threshold**: {failure_threshold} consecutive failures
**Environment gated**: {environment | "none"}

### Failure Timeline

| Run | Started | Conclusion | Link |
|-----|---------|------------|------|
| #{run_id_1} | {timestamp_1} | ❌ failure | [View]({url_1}) |
| #{run_id_2} | {timestamp_2} | ❌ failure | [View]({url_2}) |
| #{run_id_3} | {timestamp_3} | ❌ failure | [View]({url_3}) |

### Last Error Snippet

\`\`\`
{last_50_lines_of_job_log}
\`\`\`

### Suggested Remediation

- Review the error snippet above for root cause
- If App Service startup errors are present, run the `self-healing-ci` agent
- Check recent commits merged to this branch for regressions
- Inspect dependency updates or environment configuration changes

### Resolution Checklist

- [ ] Root cause identified
- [ ] Fix merged or configuration corrected
- [ ] Next CI run passes `{job_name}`
- [ ] Deployment gate removed (if applicable)
- [ ] This issue closed

> Opened automatically by the `ci-failure-escalation` agent.
```

## GitHub CLI Commands Reference

```bash
# List recent workflow runs
gh run list --repo {repo} --workflow {workflow_name} --limit {failure_threshold + 2} --json databaseId,conclusion,createdAt,url

# Get job results for a specific run
gh run view {run_id} --repo {repo} --json jobs --jq '.jobs[] | select(.name == "{job_name}") | {conclusion, startedAt, completedAt}'

# Fetch last 50 lines of job log
gh run view {run_id} --repo {repo} --log | grep -A 50 "^{job_name}"

# Open blocking issue
gh issue create --repo {repo} \
  --title "🚨 CI halt: {job_name} has failed {N} times consecutively" \
  --label "blocker" \
  --body "{issue_body}"

# Add deployment environment protection rule (requires admin token)
gh api --method POST \
  repos/{repo}/environments/{environment}/deployment-branch-policies \
  --field name="refs/heads/BLOCKED" \
  --field type="branch"

# Post check annotation on the failing run
gh api --method POST \
  repos/{repo}/check-runs \
  --field name="CI Halt Gate" \
  --field head_sha="{head_sha}" \
  --field status="completed" \
  --field conclusion="failure" \
  --field output[title]="CI halted — see issue #{issue_number}" \
  --field output[summary]="Job '{job_name}' has failed {N} consecutive times. Deploys gated. See: {issue_url}"
```

## Output

The agent produces a structured report after each invocation:

```yaml
ci_failure_escalation_report:
  repo: "{repo}"
  workflow: "{workflow_name}"
  job: "{job_name}"
  consecutive_failures: {N}
  threshold: {failure_threshold}
  status: "HALTED | MONITORING | CLEAR"
  blocking_issue_url: "{url | null}"
  environment_gated: "{environment | null}"
  gate_method: "api | manual | none"
  next_action: |
    {
      HALTED:     "Fix the root cause, merge a green run, then close the blocking issue."
      MONITORING: "{threshold - N} more failures will trigger escalation. Review {workflow_name} logs."
      CLEAR:      "No consecutive failures detected. Pipeline is healthy."
    }
```

## Integration with self-healing-ci

This agent and `self-healing-ci` form a two-tier response:

| Tier | Agent | Role |
|------|-------|------|
| 1 — Remediate | `self-healing-ci` | Automatically retries, clears caches, quarantines flaky tests |
| 2 — Escalate | `ci-failure-escalation` | Halts the line and gates deploys when tier-1 fixes are not working |

Invoke `self-healing-ci` first on isolated failures. Invoke `ci-failure-escalation` when failures are recurring across multiple runs or when you need a deployment gate regardless of automated remediation.

## Safety Guardrails

- **Read-only by default**: The agent only reads run data and reports status until the threshold is crossed
- **Idempotent issue creation**: Before opening a new blocking issue, the agent checks for an existing open issue with the same title to avoid duplicates
- **Gate removal requires explicit action**: The deployment gate is never removed automatically; the team must close the issue and run the provided removal command
- **Token scopes documented**: Branch protection rule changes require a token with `repo` or `admin:repo_hook` scope; the agent warns clearly if the token lacks permission and falls back to manual gate instructions
