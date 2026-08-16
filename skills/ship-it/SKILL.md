---
name: ship-it
compatibility: [github-copilot-cli]
description: "Convert a delivery intent (`ship-it`, `spec-2-prod`, `onboarding-conductor`) into a governed execution plan. USE FOR: governed delivery dispatch, phase/sprint issue creation, risk-band promotion gates. DO NOT USE FOR: ungated production deploys, ad hoc bugfixes, bypassing approval policies."

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

Turn a delivery goal into a governed execution bundle.

## Shortcut Phrases

- ship it
- spec to prod

## Inputs

1. `intent`: `ship-it`, `spec-2-prod`, or `onboarding-conductor`
2. `goal`: delivery objective
3. `target_repo`: `owner/repo`
4. `spec_ref` (optional): PRD/spec reference
5. `risk_band`: `low|medium|high|critical`
6. `profile` (optional, onboarding-conductor): `solo-dev|team-dev|regulated-team|pilot-luxesite`
7. `dry_run` (default `true`); `max_cycles` (default `10`); `max_retries` (default `2`)

## Workflow

1. Validate the intent contract.
2. Dispatch `.github/workflows/ship-it-intent-dispatch.yml`.
3. Generate parent goal and phase/sprint child issues with governance checklists.
4. Label for risk, intent, and control-plane tracking.
5. Run build-break guard (`ship-it-build-guard.yml`) for failure classification and recovery.
6. Run release gate (`ship-it-release-gate.yml`) for risk-band gates and promotion.
7. Hand off to `orchestrator` or `agentic-sdlc-autonomy`.

## Persistent Loop Operation

Operate as bounded cycles with state carry-forward:

1. Record `cycle_id`, `phase`, `objective`, `stop_condition`, and `max_cycles`.
2. Emit a per-cycle summary — completed actions, status snapshot, retry state, gate/evidence status, blockers, and next action or stop reason (full structure in References).
3. Continue only while the stop condition is unmet and convergence remains viable.
4. Stop and escalate when blocked or `max_cycles` is reached.

Stop conditions: unresolved dependency/policy gate; in-scope PRs merged/closed with checks green; manual stop.

Retry policy: retry only transient failures; escalate after `max_retries`; in `dry_run`, output planned actions.

## Governance Rules

1. Never bypass required checks for high/critical goals.
2. Require evidence links for spec, tests, rollout, rollback.
3. Use serialized merges for release work.
4. Record state transitions and blockers in issues.
5. Do not complete with required checks pending.

## Output

Emits parent/child issue URLs, intent-dispatch and build-break JSON summaries, a
promotion-evidence bundle, lane-aware pilot artifacts, a completeness scorecard,
spec-drift findings, and per-cycle summaries.

## References

| File | Contents |
|---|---|
| [`references/output-contract.md`](references/output-contract.md) | Output contract: per-producer output schemas, evidence-bundle fields, scorecard and spec-drift shapes, per-cycle summary structure |
