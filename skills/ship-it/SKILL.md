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
allowed-tools: [git, gh, powershell, bash]
---
# Ship-it Skill

Turn a delivery goal into a governed execution bundle.

## Shortcut Phrases

- ship it / spec to prod

## Inputs

1. `intent`: `ship-it`, `spec-2-prod`, or `onboarding-conductor`
2. `goal`, `target_repo` (`owner/repo`), `spec_ref` (optional)
3. `risk_band`: `low|medium|high|critical`
4. `profile` (optional, onboarding-conductor): `solo-dev|team-dev|regulated-team|pilot-luxesite`
5. `dry_run` (default `true`); `max_cycles` (default `10`); `max_retries` (default `2`)

## Workflow

1. Validate the intent contract.
2. Preflight: confirm `ship-it-intent-dispatch.yml`, `ship-it-build-guard.yml`,
   and `ship-it-release-gate.yml` exist under `.github/workflows/`. If any is
   missing, stop and report it — never substitute `/approve` (full fail-closed
   contract in References).
3. Dispatch `ship-it-intent-dispatch.yml`; record its run ID.
4. Generate parent/child issues with governance checklists.
5. Label for risk, intent, and control-plane tracking.
6. Run build-break guard (`ship-it-build-guard.yml`) for failure classification and recovery.
7. Run release gate (`ship-it-release-gate.yml`) for risk-band gates and promotion.
8. Report success only with observable run IDs and state transitions.

## Persistent Loop Operation

Operate as bounded cycles with state carry-forward:

1. Record `cycle_id`, `phase`, `objective`, `stop_condition`, `max_cycles`.
2. Emit a per-cycle summary (full structure in References).
3. Continue only while the stop condition is unmet and convergence is viable.
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

Emits issue URLs, dispatch/build-break summaries, a promotion-evidence bundle,
pilot artifacts, a completeness scorecard, spec-drift findings, and per-cycle summaries.

## References

| File | Contents |
|---|---|
| [`references/output-contract.md`](references/output-contract.md) | Output contract: per-producer output schemas, evidence-bundle fields, scorecard and spec-drift shapes, per-cycle summary structure |
