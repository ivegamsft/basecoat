# Ship-it Output Contract

Reference for the artifacts the ship-it skill emits. The `## Output` section of
`SKILL.md` summarizes these; this file describes each producer's emitted fields.
The producing scripts (cited with file:line) are authoritative for exact field
shapes — consult them when integrating, as fields may evolve.

## Producers

| Source | Emits |
|---|---|
| `ship-it-intent-dispatch.yml` → `scripts/ship-it/dispatch-intent.ps1` | Intent dispatch summary (issue graph, desired-state diff, promotion contract). |
| `ship-it-build-guard.yml` → `scripts/ship-it/build-break-detector.ps1` | Build-break summary JSON + companion `.md` (`test-results/ship-it/build-break-summary.{json,md}`, artifact `ship-it-build-break`). |
| `ship-it-release-gate.yml` → `scripts/ship-it/invoke-release-gate.ps1` → `scripts/ship-it/release-gate-enforcer.ps1` | Full release-gate evidence bundle (`promotion_allowed`, blockers, completeness scorecard + spec-drift) at `test-results/ship-it/promotion-evidence-bundle.{json,md}`, surfaced in the job summary and uploaded as the `ship-it-release-gate` artifact. The `invoke-release-gate.ps1` wrapper parses the workflow's grouped `key=value` inputs (`gate_status`, `artifact_status`, `promotion_context`) into enforcer parameters. |

## Intent dispatch summary

`dispatch-intent.ps1` `$summary` (lines 632-656). Selected fields:

| Field | Description |
|---|---|
| `intent` | `ship-it`, `spec-2-prod`, or `onboarding-conductor`. |
| `goal`, `target_repo`, `risk_band`, `profile`, `spec_ref` | Run inputs (trimmed goal). |
| `started_at`, `dry_run`, `run_key`, `run_key_hash` | Run metadata and idempotency key. |
| `desired_state_diff[]` | `{ surface, current_state, desired_state, action }`. |
| `release_gate_contract` | `{ workflow, promotion_order, evidence_bundle_output }`. |
| `remediation_tasks[]` | `{ name, owner, status }`. |
| `parent_issue_url`, `parent_issue_number`, `parent_issue_reused` | Parent goal issue. |
| `child_issues[]` | `{ sprint, phase, url, number, reused, stage_artifact }` — one per stage. |

`stage_artifact` (lines 374-394) carries the lane-aware execution contract:
`{ stage, execution_lane, branch_name, pr_title, pr_search_query,
previous_stage_issue_url, merge_policy{ sequencing, required_checks,
merge_ready_condition, sync_with_latest_main, wait_for_previous_stage,
rebase_before_merge }, cleanup_policy{ workflow, script, audit_log } }`.

## Build-break summary

`build-break-detector.ps1` `$summary` (lines 413-432) → JSON + companion `.md`:

| Field | Description |
|---|---|
| `observed_at`, `target_repo`, `target_branch`, `workflow_name`, `source_run_id` | Detection context. |
| `max_auto_retries`, `current_retry_count`, `next_retry_count`, `consecutive_failures` | Retry budget and failure streak. |
| `status` | `CLEAR`, `RETRYING`, or `ESCALATED`. |
| `action` | `no_action`, `retry`, or `escalate`. |
| `reason` | Recoverable/nonrecoverable/retry-exhausted classification reason. |
| `latest_failure` | `{ run_id, created_at, conclusion, url }`; `null` when `CLEAR`. |
| `failure_trend[]` | Up to 5 recent failing runs (same shape). |
| `classifier` | `{ category, recoverable, confidence, evidence, recommendation }`; `null` when `CLEAR`. |
| `retry_command` | `gh run rerun ... --failed`; empty string when not retrying. |
| `escalation_issue_url` | Set on escalation; empty string otherwise, including during dry-run escalation. |
| `dry_run` | Boolean. |

## Release gate evidence

The `ship-it-release-gate.yml` workflow invokes
`scripts/ship-it/release-gate-enforcer.ps1` (`$summary`, lines 535-571) through
the `scripts/ship-it/invoke-release-gate.ps1` wrapper, which parses the grouped
`key=value` dispatch inputs (`gate_status`, `artifact_status`,
`promotion_context`) into enforcer parameters and fails closed on malformed,
unknown, duplicate, or empty status tokens. The enforcer writes the full
governance record to `test-results/ship-it/promotion-evidence-bundle.json`
plus a companion `.md` (appended to the job summary and uploaded as the
`ship-it-release-gate` artifact). Outside a dry run the gate fails (exit 1)
when `promotion_allowed` is false. The record contains `promotion_allowed`,
`blockers[]`, `progressive_promotion`, `required_gates`/`failed_required_gates`,
`lane_policy`, `environment_protection`, `rollback_contract`, `evidence_bundle`,
plus:

- `artifact_completeness` — completeness scorecard:
  `{ change_type, required_artifacts, required_count, present_required_count,
  score_percent, scorecard[], runbook_delta, release_notes_delta }`. Each
  `scorecard[]` entry (lines 398-409) is `{ artifact, required, status, present,
  goal_ids, missing_goal_ids, extra_goal_ids, coverage_percent, drifted,
  remediation }`. Each `*_delta` is `{ goal_ids, missing_goal_ids, extra_goal_ids }`.
- `spec_drift` — `{ has_drift, contract_goal_ids, spec_goal_ids,
  implementation_goal_ids, missing_from_spec, missing_from_implementation,
  undocumented_implementation_goals, remediation_suggestions[] }`.

## Per-cycle summaries

Persistent-loop operation is agent-maintained (not a producer JSON field). Each
cycle the skill reports: `cycle_id`, `phase`, and `objective`; completed actions;
a status snapshot (tasks, open PRs, required checks); retry state; gate/evidence
status; blockers; the next action; and an explicit `stop_condition_status`
(`continue|complete|blocked|max_cycles|manual_stop`).
