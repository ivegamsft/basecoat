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

## Workflow

1. Validate the intent contract.
2. Run `pwsh scripts/ship-it/validate-target-repository.ps1
   -TargetRepo <owner/repo>`. The target must match the current repository;
   cross-repository execution requires explicit user authorization and
   `-AllowCrossRepository` (see References).
3. Confirm `ship-it-intent-dispatch.yml`, build-guard, and release-gate
   workflows exist. If any is missing, stop and report it; never substitute
   `/approve`.
4. Dispatch `ship-it-intent-dispatch.yml` and record its run ID.
5. Create governed issues, apply tracking labels, run build-break and release gates.
6. Report success only with observable run IDs and state transitions.

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

## References

| File | Contents |
|---|---|
| [`references/output-contract.md`](references/output-contract.md) | Output contract: per-producer output schemas, evidence-bundle fields, scorecard and spec-drift shapes, per-cycle summary structure |
| [`references/repository-boundary.md`](references/repository-boundary.md) | Fail-closed current-repository validation and explicit cross-repository authorization |
