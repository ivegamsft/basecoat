---
name: ship-it
compatibility: [github-copilot-cli]
description: "Use when converting a delivery intent (`ship-it`, `spec-2-prod`, or `onboarding-conductor`) into a governed execution plan with live issue side effects. USE FOR: dispatching ship-it intents, creating tracked phase/sprint issue bundles, enforcing risk-band governance checklists, and handing intent execution to orchestration agents. DO NOT USE FOR: direct production deployment without gates, ad hoc one-off bugfixes, or bypassing approval policies."

category: workflow
visibility: public
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---
# Ship-it Skill

Use this skill to start intent-driven delivery from a single goal statement and
turn it into a governed, trackable execution bundle.

## Shortcut Phrases

- ship it
- spec to prod
- start intent execution
- launch governed delivery loop

## Inputs

1. `intent`: `ship-it`, `spec-2-prod`, or `onboarding-conductor`
2. `goal`: short delivery objective
3. `target_repo`: `owner/repo`
4. `spec_ref` (optional): PRD/spec URL or path
5. `risk_band`: `low | medium | high | critical`
6. `profile` (optional): `solo-dev | team-dev | regulated-team | pilot-luxesite` (onboarding-conductor only)
7. `dry_run` (optional): `true|false`
8. `max_cycles` (optional): bounded cycle cap for loop mode
9. `max_retries` (optional): retry cap per failed subtask

## Workflow

1. Validate the intent contract.
2. Dispatch `.github/workflows/ship-it-intent-dispatch.yml`.
3. Generate parent goal issue and phase/sprint child issues with governance checklists.
4. Add labels for risk, intent, and control-plane tracking.
5. Run build-break guard (`.github/workflows/ship-it-build-guard.yml`) for failure classification and bounded recovery.
6. Run release gate enforcement (`.github/workflows/ship-it-release-gate.yml`) to evaluate risk-band gates and staged promotion policy.
7. Hand off execution to `orchestrator` or `agentic-sdlc-autonomy`.

## Persistent Loop Operation

Operate as bounded cycles with explicit state carry-forward between cycles:

1. Record `cycle_id`, `phase`, `objective`, `stop_condition`, and `max_cycles`.
2. Emit a compact cycle summary after each loop.
3. Continue only when the stop condition is not yet met and convergence remains viable.
4. Stop and escalate when blocked or when `max_cycles` is reached.
5. Build a cycle status summary from active tasks, open PRs, and required checks.

Cycle summary contract:

1. phase/objective
2. completed actions
3. gate/evidence status
4. blockers
5. next action or stop reason

Stop conditions:

1. Blocked by unresolved dependency/policy gate.
2. All in-scope PRs merged/closed with required checks green.
3. Manual stop command.

Retry policy:

1. Retry only transient subtask failures.
2. Escalate after `max_retries` per subtask.
3. In `dry_run`, output planned retries/escalations only.

## Governance Rules

1. Never bypass required checks for high/critical risk goals.
2. Require explicit evidence links for spec, tests, rollout, and rollback.
3. Use serialized merges for release-affecting work.
4. Record state transitions and blockers in issue artifacts.
5. Do not mark workflow complete while required checks are pending.

## Output

- Parent goal issue URL
- Child phase/sprint issue URLs
- JSON summary artifact for automation, desired-state diff, and remediation tracking
- Lane-aware stage artifacts for pilot onboarding paths (for example, `pilot-luxesite-*` phase lanes)
- Build-break detection summary artifacts (`build-break-summary.json` and `build-break-summary.md`) for retry/escalation visibility
- Promotion evidence bundle (`promotion-evidence-bundle.json` and `promotion-evidence-bundle.md`) with immutable references and gate decisions
- Artifact completeness scorecard with risk/change-band matrix enforcement
- Spec drift findings with remediation suggestions and goal-ID linked runbook/release-note deltas
- Cycle summaries with explicit stop-condition status for each loop iteration
