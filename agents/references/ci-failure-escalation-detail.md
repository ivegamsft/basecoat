# CI Failure Escalation — Detail Reference

Full detail supporting `agents/basecoat-60-workflow-ci-failure-escalation.agent.md`.

## Escalation Issue Template

The blocking issue body follows this structure:

The issue title is a **stable marker** (`CI halt: {repo}/{workflow_name}/{job_name}`) that does not embed the failure count, so later failures update the same issue via search-and-comment instead of opening a duplicate blocker each time the count changes.

~~~~markdown
## CI Halt — {job_name}

**Workflow**: `{workflow_name}`
**Job**: `{job_name}`
**Consecutive failures**: {N} (threshold {failure_threshold})
**Environment gated**: {environment | "none"}

### Failure Timeline

| Run | Started | Conclusion | Link |
|-----|---------|------------|------|
| #{run_id_1} | {timestamp_1} | failure | [View]({url_1}) |
| #{run_id_2} | {timestamp_2} | failure | [View]({url_2}) |
| #{run_id_3} | {timestamp_3} | failure | [View]({url_3}) |

### Last Error Snippet

~~~
{last_50_lines_of_job_log}
~~~

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

> Opened/updated automatically by the `ci-failure-escalation` agent.
~~~~

## GitHub CLI Commands Reference

~~~bash
# List recent workflow runs — quote workflow_name as one argument since display
# names may contain spaces (e.g. "BaseCoat - CI")
gh run list --repo {repo} --workflow "{workflow_name}" --limit {failure_threshold + 2} --json databaseId,conclusion,createdAt,url

# Get the job ID for a specific run. `gh --jq` takes exactly one filter
# expression (it does not forward jq CLI flags like --arg), so pipe the raw
# JSON to external jq instead, passing job_name as --arg data rather than
# interpolating it into the program, so a name containing a quote cannot
# break out of the filter
job_id=$(gh run view {run_id} --repo {repo} --json jobs \
  | jq --arg job "{job_name}" -r '.jobs[] | select(.name == $job) | .databaseId')

# Fetch last 50 lines of that job's log
gh api "repos/{repo}/actions/jobs/${job_id}/logs" | tail -n 50

# Find or update the existing blocking issue by a stable marker (not the count).
# Build the marker as data (never interpolated into a shell string or search
# query), fetch open "blocker" issues, and require an exact title match before
# treating one as the existing blocker — a fuzzy/partial search match could
# otherwise update the wrong issue.
issue_title=$(cat <<'TITLE_EOF'
CI halt: {repo}/{workflow_name}/{job_name}
TITLE_EOF
)
existing_issue=$(gh issue list --repo {repo} --state open --label "blocker" --json number,title \
  | jq -r --arg title "$issue_title" '.[] | select(.title == $title) | .number' | head -n1)
if [ -n "$existing_issue" ]; then
  gh issue comment "$existing_issue" --repo {repo} --body-file issue-body.md
else
  gh issue create --repo {repo} --title "$issue_title" --label "blocker" --body-file issue-body.md
fi

# Gate an environment (requires repo admin permission and explicit Tier-3
# confirmation restating target repo/environment/impact before deletion — see
# docs/reference/guardrails/tool-confirmation-policy.md). Custom deployment
# branch policies only take effect when the environment is in custom-policy
# mode; if it is `protected_branches` or unrestricted, the policy list is empty
# while deployments remain allowed, so check the mode first.

# 1. Confirm the environment is in custom-policy mode (only then does clearing
#    the policy list actually block deploys)
gh api "repos/{repo}/environments/{environment}" --jq '.deployment_branch_policy.custom_branch_policies'

# 2. Snapshot existing policies (id, name, and type — branch vs tag) for exact
#    rollback. This endpoint paginates at 30 per page by default, so use
#    --paginate to aggregate every page — otherwise policies past the first
#    page are silently dropped from the snapshot and the gate/restore is incomplete
gh api --paginate "repos/{repo}/environments/{environment}/deployment-branch-policies" \
  --jq '.branch_policies[] | {id, name, type}' > policies-snapshot.json

# 3. Remove each existing policy ID (from the snapshot) so no branch or tag is allowed to deploy
gh api --method DELETE "repos/{repo}/environments/{environment}/deployment-branch-policies/{policy_id}"

# 4. Verify the gate: confirm the policy list is now empty
gh api --paginate "repos/{repo}/environments/{environment}/deployment-branch-policies" --jq '.branch_policies | length'


# 5. On resolution, recreate each policy from policies-snapshot.json using its
#    original name/type (GitHub assigns each recreated policy a new id — the
#    snapshotted id is only used above to target the original DELETE calls)
gh api --method POST "repos/{repo}/environments/{environment}/deployment-branch-policies" \
  --field name="{restored_pattern}" \
  --field type="{restored_type}"

# Post a new failing check run referencing the halt (not an annotation on the original run) —
# build the summary via a single-quoted heredoc first for the same shell-injection reason as above
check_summary=$(cat <<'SUMMARY_EOF'
Job '{job_name}' has failed {N} consecutive times. Deploys gated. See: {issue_url}
SUMMARY_EOF
)
gh api --method POST \
  repos/{repo}/check-runs \
  --field name="CI Halt Gate" \
  --field head_sha="{head_sha}" \
  --field status="completed" \
  --field conclusion="failure" \
  --field output[title]="CI halted — see issue #{issue_number}" \
  --field output[summary]="$check_summary"
~~~

## Output Report Schema

~~~yaml
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
  gated_policy_snapshot: "[{id, name, type}, ...] | null"  # id targets the original DELETE calls; name/type are recreated on resolution (GitHub assigns each recreated policy a new id)
  next_action: |
    {
      HALTED:     "Fix the root cause, merge a green run, then recreate the policies from gated_policy_snapshot and close the blocking issue."
      MONITORING: "{threshold - N} more failures will trigger escalation. Review {workflow_name} logs."
      CLEAR:      "No consecutive failures detected. Pipeline is healthy."
    }
~~~

## Integration with self-healing-ci

This agent and `self-healing-ci` form a two-tier response:

| Tier | Agent | Role |
|------|-------|------|
| 1 — Remediate | `self-healing-ci` | Automatically retries, clears caches, quarantines flaky tests |
| 2 — Escalate | `ci-failure-escalation` | Halts the line and gates deploys when tier-1 fixes are not working |

Invoke `self-healing-ci` first on isolated failures. Invoke `ci-failure-escalation` when failures are recurring across multiple runs or when you need a deployment gate regardless of automated remediation.

## Safety Guardrails

- **Read-only by default**: The agent only reads run data and reports status until the threshold is crossed
- **Idempotent issue tracking**: The blocking issue is keyed by a stable `repo`/`workflow_name`/`job_name` marker, not the failure count, so repeated failures update the existing issue instead of opening duplicates
- **Gate only works on custom-policy environments**: The agent verifies `custom_branch_policies: true` before attempting to gate; on `protected_branches`/unrestricted environments it falls back to manual instructions instead of reporting a false gate
- **Explicit confirmation before deletion**: Deleting deployment branch policies is a Tier-3 production-impacting action (`docs/reference/guardrails/tool-confirmation-policy.md`); the agent restates the target repo/environment and impact and requires confirmation immediately before deleting
- **Gate removal requires explicit action and the snapshot**: The deployment gate is never removed automatically; the team must close the issue, and resolution recreates each snapshotted policy's `name`/`type` (the snapshotted `id` is only used to target the original DELETE calls — GitHub assigns a new `id` when a policy is recreated, so the snapshot is not restored as identical records)
- **Token permissions documented**: Branch protection and deployment-branch-policy changes require repository admin permission (a fine-grained PAT with "Administration" write access, or a classic token with `repo` scope on a repo the caller administers); `admin:repo_hook` only covers webhooks and is not sufficient. The agent warns clearly if the token lacks permission and falls back to manual gate instructions
