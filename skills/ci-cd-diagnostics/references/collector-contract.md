# CI/CD Diagnostics Collector Contract

## Purpose

Define deterministic retrieval paths, formulas, and blocked-state handling for
every required metric in the CI/CD diagnostics output.

## Global rules

1. Every output row must include `Metric | Value | Source/command used`.
2. Never estimate missing values.
3. If unavailable, output `BLOCKED: <reason>` and include the failed command,
   endpoint, or missing capability in `Source/command used`.
4. Time windows:
   - 14-day metrics use `now - 14 days` (UTC)
   - 2-week queue/conflict metrics use same 14-day window
   - weekly backlog deltas use 4 rolling 7-day buckets

## Metric retrieval map

| Metric | Retrieval path | Formula |
|---|---|---|
| Active agents/bots with open PRs or commits in last 14 days | `gh pr list --state open --limit 1000 --json author`; `gh api /repos/{owner}/{repo}/commits?since=<iso>&per_page=100` (paginate) | Count unique bot/agent identities across both sources |
| Issues created/day (14-day avg) | `gh issue list --state all --limit 1000 --search "created:>=<date>" --json createdAt` | `count(created in window) / 14` |
| Issues closed/day (14-day avg) | `gh issue list --state closed --limit 1000 --search "closed:>=<date>" --json closedAt` | `count(closed in window) / 14` |
| Current open issue count | `gh issue list --state open --limit 1000 --json number` | `count(open issues)` |
| Current open PR count | `gh pr list --state open --limit 1000 --json number` | `count(open PRs)` |
| Avg PR open -> first CI result (last 50 merged) | `gh pr list --state merged --limit 50 --json number,createdAt`; per PR: `gh pr view <n> --json statusCheckRollup,createdAt` | `avg(min(statusCheckRollup.contexts[].completedAt) - createdAt)` |
| Avg PR open -> merged (last 50 merged) | `gh pr list --state merged --limit 50 --json createdAt,mergedAt` | `avg(mergedAt - createdAt)` |
| Avg lines changed per PR (last 50 merged) | `gh pr list --state merged --limit 50 --json additions,deletions` | `avg(additions + deletions)` |
| Percent touching >3 files (last 50 merged) | `gh pr list --state merged --limit 50 --json changedFiles` | `100 * count(changedFiles > 3) / total` |
| Full CI suite runtime (single full run on main) | `gh run list --workflow ci.yml --branch main --status completed --limit 1 --json startedAt,updatedAt` | `updatedAt - startedAt` |
| Full-suite vs affected-only confirmation | Inspect workflow YAML triggers/jobs (`.github/workflows/*.yml`) and/or run usage metadata | Categorical: `full-suite-every-pr` or `affected-only/mixed` |
| Merge queue tool in use | Inspect repo settings/workflow references (`merge_group`, Mergify/Bors markers) | Categorical: `github-queue`, `mergify`, `bors`, `custom`, `none` |
| Batch size per merge attempt | Merge queue config/log source | Numeric batch size (`1` if serial) |
| Avg queue wait before merge attempt | Queue-triggered run timestamps | `avg(attempt_start - queue_entry_time)` |
| Percent failed and requeued attempts (2 weeks) | Queue events/logs in 14-day window | `100 * failed_requeued / total_attempts` |
| Merge conflict count (2 weeks) | PR conflict states, failed rebase/merge-check logs | `count(conflict events)` |
| Conflict details (files/modules + branches/agents) | PR/log evidence per conflict | Row-per-conflict detail |
| Ownership overlap prevention present | `CODEOWNERS` + enforcement workflow check | `Yes/No` plus mechanism text |
| Sprint length in days | Milestone metadata (`created/due`) or documented sprint cadence | Numeric day count |
| Merge timestamp distribution across sprint | PR mergedAt timestamps + sprint window | Bucket counts: first 20%, middle 60%, last 20% |
| Percent merged in last 20% | Same as above | `100 * bucket_last20 / total_sprint_prs` |
| Weekly net issue delta (4 weeks) | Issues created/closed timestamps in 28-day window | Per week: `created - closed` |
| Issue creation cap/throttle exists | Repo automation/workflow policy inspection | `Yes/No` plus mechanism |

## Blocked-state taxonomy

Use one of these exact prefixes:

- `BLOCKED: missing permission` (insufficient GitHub scope/API access)
- `BLOCKED: tool not installed` (required tool absent)
- `BLOCKED: metric not tracked` (no source emits the required signal)
- `BLOCKED: unsupported endpoint` (API source does not expose needed field)
- `BLOCKED: ambiguous source-of-truth` (multiple conflicting sources, no policy)

## Required blocked row format

| Metric | Value | Source/command used |
|---|---|---|
| `<metric name>` | `BLOCKED: <reason>` | `<failed command or missing source>` |
