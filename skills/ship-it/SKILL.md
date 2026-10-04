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
2. Unattended pre-approval requires both `source_issue_number` and
   `approval_comment_id`; one alone fails, neither preserves ordinary dispatch.
   Never accept caller-supplied identity, permission, timestamp, or approval
   status. The live evidence and scope contract is defined in
   [output-contract.md](references/output-contract.md).
3. Run `pwsh scripts/ship-it/validate-target-repository.ps1
   -TargetRepo <owner/repo>`. Cross-repository execution requires explicit user
   authorization and `-AllowCrossRepository` (see References).
4. Verify dispatch, build-guard, and release-gate workflows exist; otherwise
   stop and report, never substitute `/approve`.
5. Dispatch `ship-it-intent-dispatch.yml` and record its run ID and receipt.
6. Revalidate the same receipt before each phase, merge, and release. Missing,
   changed, revoked, or newly unqualified evidence blocks continuation; never
   switch approvals. Pass the receipt to the local resolver or in
   `promotion_context` for the release gate (see output contract).
7. Create governed issues, apply tracking labels, and run build-break and release gates.
8. Report success only with observable run IDs and state transitions.

## Persistent Loop Operation

Use bounded cycles with state carry-forward. Record the cycle, phase, objective,
stop condition, and limit; summarize actions, status, evidence, blockers, and
next action. Continue only while convergence is viable. Stop on completion,
blocker, manual stop, or cycle limit; retry only transient failures up to the
retry limit. In `dry_run`, report planned actions.

## Governance Rules

Keep required checks and spec, test, rollout, and rollback evidence; serialize
release merges and record transitions and blockers. Do not complete with checks
pending. Issue pre-approval does not satisfy PR review, XXL, release, or
production gates or expand scope. Never copy approval to generated issues;
validate authority against the live source.

## References

| File | Contents |
|---|---|
| [`references/output-contract.md`](references/output-contract.md) | Output contract: per-producer output schemas, evidence-bundle fields, scorecard and spec-drift shapes, per-cycle summary structure |
| [`references/repository-boundary.md`](references/repository-boundary.md) | Fail-closed current-repository validation and explicit cross-repository authorization |
