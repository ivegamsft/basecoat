---
on:
  workflow_run:
    workflows:
      - CI
    branches: [main]
    types: [completed]
  workflow_dispatch:
    inputs:
      run_id:
        description: "Workflow run ID to analyze (optional)"
        required: false
        type: string
permissions:
  contents: read
  actions: read
  issues: read
  pull-requests: read
safe-outputs:
  add-comment:
    hide-older-comments: true
  create-issue:
    max: 1
    close-older-issues: true
concurrency:
  group: "gh-aw-${{ github.workflow }}-${{ github.event.workflow_run.head_sha || github.event.workflow_run.id || inputs.run_id || github.run_id }}"
  cancel-in-progress: true
engine: copilot
timeout-minutes: 20
run-name: "Self-Healing CI — run ${{ github.event.workflow_run.id || inputs.run_id || github.run_id }}"
---

# Self-Healing CI — Automated Failure Diagnosis

You are analyzing a failed GitHub Actions workflow run and providing actionable
diagnosis and remediation guidance.

## Context

- **Failed workflow run ID**: `${{ github.event.workflow_run.id }}`
- **Commit SHA**: `${{ github.event.workflow_run.head_sha }}`
- **Conclusion**: `${{ github.event.workflow_run.conclusion }}`
- **Repository**: `${{ github.repository }}`
- **Watched workflow**: `CI` on `main` only (to avoid redundant workflow_run fan-out)
- **Auto mode guard**: automatic `workflow_run` handling is gated by repo variable `SELF_HEALING_CI_AUTO=true` (disabled by default when unset).

Fetch full workflow run details using:

```bash
gh run view ${{ github.event.workflow_run.id }} --repo ${{ github.repository }} --json name,headBranch,conclusion,status,jobs
```

## What to Do

Only act if the conclusion from the run details is `failure` or `timed_out`.
If the conclusion is `success`, `cancelled`, or `skipped`, post nothing and exit.

### Step 1 — Fetch Failed Job Logs

```bash
# Get all jobs for this run
gh run view ${{ github.event.workflow_run.id }} --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {id: .databaseId, name: .name, conclusion: .conclusion}'

# Get logs for each failed job
gh run view --log-failed ${{ github.event.workflow_run.id }} 2>&1 | head -500
```

### Step 2 — Classify the Failure

Determine the root cause category:

| Category | Signals |
|---|---|
| **Test failure** | `FAIL`, assertion errors, test output with `×` or `FAILED` |
| **Build error** | Compilation errors, TypeScript errors, `error TS` |
| **Lint / validation** | `markdownlint`, `validate-basecoat`, frontmatter errors |
| **Dependency error** | `npm ERR!`, `Cannot find module`, `peer dep` conflicts |
| **Timeout** | `timed out`, `exceeded maximum time` |
| **Transient / flaky** | Network errors, rate limits, `503`, `ECONNRESET` |
| **Infrastructure** | Runner provisioning failures, Docker pull errors |

### Step 3 — Identify Root Cause

Extract the specific error message, file, and line number where the failure occurred.
Look for patterns in recent similar failures using:

```bash
gh run list --workflow="${{ github.event.workflow_run.id }}" --limit 10 --json conclusion,createdAt,headBranch
```

### Step 4 — Assess Impact

- Is this on `main` or a feature branch?
- Is this blocking a release or PR merge?
- Has this failure pattern appeared before in the last 10 runs (flaky)?

### Step 5 — Post Diagnosis Comment

If the failure is on a PR, comment on the PR. Otherwise, create an issue.
Use this structure:

```markdown
## CI Failure Diagnosis

**Workflow**: [name]
**Run**: [run-id]
**Branch**: [branch]
**Failure Category**: [category from Step 2]

### Root Cause
[Specific error message and location]

### Why It Likely Failed
[2-3 sentence explanation]

### Recommended Fix
1. [Specific action]
2. [Specific action]

### Retry?
[Yes — this looks transient | No — needs a code fix]

### Flaky?
[Yes — seen N times in last 10 runs | No — first occurrence]
```

Keep the diagnosis concise and actionable. If the failure is clearly transient
(network, rate limit), note it and suggest a manual re-run rather than filing an issue.
