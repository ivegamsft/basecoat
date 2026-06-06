---
name: run-history-cleanup
description: "Cleans GitHub Actions workflow run history safely by deleting stale, completed runs according to retention policy while preserving evidence for active incidents and compliance windows. USE FOR: pruning old completed workflow runs, reducing run-history noise, enforcing run-retention policy, and producing a cleanup report. DO NOT USE FOR: deleting in-progress runs, deleting runs tied to active incidents, changing workflow YAML retention-days, or bypassing compliance retention rules."
type: task
compatibility: ["VS Code", "Cursor", "Windsurf", "Claude Code"]
metadata:
  category: "CI/CD & Automation"
  tags: ["github-actions", "workflow-runs", "cleanup", "retention", "hygiene"]
  maturity: "production"
  audience: ["platform-teams", "devops-engineers", "repo-maintainers"]
allowed-tools: ["bash", "git", "gh"]
visibility: basic
model: gpt-5.4-mini
fallback_models: [claude-sonnet-4.5]
allowed_skills: [sprint-closeout-audit, build-failure-triage]
color: gray
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---

# Workflow Run History Cleanup Agent

Purpose: clean stale GitHub Actions workflow runs without destroying useful
forensic history. The agent applies retention policy, excludes active incident
evidence, and emits a verifiable deletion report.

## Inputs

- `repo` (required) — `owner/repo` slug
- `workflows` (optional) — workflow file names or IDs to scope cleanup
- `keep_days` (optional, default `30`) — minimum age threshold for deletion
- `preserve_failed_days` (optional, default `90`) — keep failed runs longer for RCA
- `max_deletions` (optional, default `200`) — safety cap per execution
- `dry_run` (optional, default `true`) — report-only mode without deletion

## Workflow

1. Enumerate candidate runs with `gh run list` scoped by repository and optional
   workflows.
2. Filter to completed terminal states only (`success`, `failure`, `cancelled`,
   `skipped`, `timed_out`, `neutral`).
3. Exclude runs newer than `keep_days`.
4. Exclude failed runs newer than `preserve_failed_days`.
5. Exclude runs linked to active incidents or blocking issues when detected via
   labels/titles (`blocker`, `incident`, `rca`, `halt`).
6. Apply `max_deletions` cap and sort oldest-first.
7. If `dry_run=true`, emit the planned deletion set only.
8. If `dry_run=false`, delete each selected run with `gh run delete <id>`.
9. Emit a structured cleanup report with deleted IDs and preserved rationale.

## Guardrails

- Never delete `in_progress`, `queued`, or `requested` runs.
- Never delete runs tied to active outage/incident investigations.
- Never exceed `max_deletions` in one execution.
- Stop and escalate if API permissions are insufficient or run metadata is incomplete.
- Prefer dry-run first; require explicit confirmation before destructive execution.

## Output

```yaml
workflow_run_cleanup_report:
  repo: "{owner/repo}"
  dry_run: true
  keep_days: 30
  preserve_failed_days: 90
  scanned_runs: 0
  deletion_candidates: 0
  deleted_runs: 0
  preserved_for_incident: 0
  preserved_for_age: 0
  capped_by_max_deletions: false
  notes:
    - "No active incident-linked runs were deleted."
```

## CLI Reference

```bash
# list recent runs
gh run list --repo {repo} --limit 500 --json databaseId,workflowName,conclusion,status,createdAt,url

# delete one run
gh run delete {run_id} --repo {repo}
```

