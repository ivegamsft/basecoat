---
issue: 3465
title: "Consumer rollout refresh omits downstream workflow onboarding and installed validation"
status: draft
author: ibuyspy
created: 2026-10-03
labels: ["enhancement", "needs-prd", "synthesize-spec"]
---

# Spec: Consumer rollout refresh omits downstream workflow onboarding and installed validation

## Problem Statement

The official v4.5.2 rollout-basecoat skill resolves .basecoat.yml sync.script and runs only the sync entrypoint before committing the consumer upgrade. Root sync refreshes managed workflow sources and runtime scripts, while active .github/workflows files require configure-downstream-workflows.ps1 separately. Existing consumers can therefore receive new runtime scripts while their active workflows remain stale. Please define and implement an official refresh/onboard contract that preserves selected install classes, runs downstream onboarding, and validates the installed payload before delivery. Affected assets: skills/rollout-basecoat/SKILL.md and the consumer update path. Consumers currently need both official steps documented explicitly. This is an issue-only report; no upstream implementation requested or included.

## Why This Matters

The existing rollout skill goes from sync/version verification to commit and PR
without refreshing active workflow installations. Managed workflow sources under
`.github/base-coat/workflows/` are inactive until configured under
`.github/workflows/`. A refreshed runtime and stale workflow can therefore form
an invalid combination even when the installed version file looks current.

## Scope

Update `skills/rollout-basecoat/SKILL.md` and its delivery reference to run the
existing installer and installed validator as part of consumer refresh. Extend
the installer only where necessary to preserve the actual installed selection
and expose a deterministic readiness report. Add fixtures and regression tests
for the consumer lifecycle. Do not introduce a second workflow installer.

First-time activation is separate from refresh. This spec does not change
approval requirements, dispatch authorization, production release gates, or
consumer update policy.

## Design Contract

### Capture before sync

1. Resolve the consumer repository and default branch using the existing rollout
   worktree procedure. Keep writes in the isolated upgrade worktree.
2. Capture active installed workflows and their source-to-destination mappings
   before sync. Use the installer registry and ownership evidence; never treat a
   filename prefix alone as permission to overwrite a repository-owned file.
3. Capture explicit install-class or targeted-workflow selections when available.
   Prefer recorded selection over inference; reject contradictory evidence.
4. Preserve consumer governance and onboarding profile choices. Sync must not
   erase the only record of selection before it has been captured.

### Refresh after sync

1. Run the resolved sync entrypoint and verify version/provenance as today.
2. Invoke `configure-downstream-workflows.ps1` from the refreshed managed runtime
   with the captured selection, using targeted installs when no class selection
   was recorded. Do not fall back to the default reusable-plus-ship-it classes.
3. A consumer with staged sources but no active managed workflows stays
   staged-only. Report the explicit activation command and permission effects;
   do not infer consent to first-time activation.
4. Treat ship-it as one three-workflow capability. A partial installation reports
   the missing members and requires explicit completion or offboarding; it must
   not silently widen selection during refresh.
5. Preserve repository-owned workflows and targeted-install governance files
   using the existing installer protections. Report collisions and unsupported
   selected workflows as actionable blockers, not successful skips.
6. Validate the resulting payload with the refreshed managed
   `validate-basecoat.ps1 -WorkflowValidationMode Consumer`, plus installer
   workflow-contract validation. Run commands from the consumer worktree.

### Delivery and readiness

Only commit/push/open the upgrade PR after installed validation succeeds. Compare
the whole resulting diff, not just `version.json`, before declaring no change.
An already-current version with stale active workflows is still a refresh.

Expose readiness fields for source version/ref, selected classes or workflow
targets, staged-only/partial/installed state, refreshed destinations, missing
dependencies, validation outcome, and the upgrade PR when one exists. Separate
local installation readiness from GitHub Actions API state: a file can exist
locally while its remote workflow is disabled. The ship-it dispatch API preflight
remains authoritative for live dispatch.

## Alternatives and Decision

- Running the installer with defaults after every sync is simple but enables
  automation the consumer never selected. Reject this fallback.
- Leaving workflow activation entirely manual preserves consent but recreates
  runtime/workflow version skew on every upgrade. Reject it for existing installs.
- Refreshing the captured selection reuses the installer and preserves consent.
  Use this approach; surface missing selection rather than guessing.

## Security and Failure Modes

- Resolve scripts and destinations within the consumer worktree and retain
  existing path/reparse-point and overlay ownership checks.
- Never copy credentials or embed tokens in readiness artifacts.
- A sync, installer, or validator failure stops delivery with its exit status and
  remediation. Do not create success-shaped placeholder evidence.
- Keep a failed worktree available for diagnosis; do not remove uncommitted
  changes or overwrite the consumer's primary worktree.
- Conflicting ownership, malformed selection, or unknown installed mappings
  block automatic refresh until explicitly resolved.
- Other product overlays remain out of scope; report any required overlay
  re-sync order rather than claiming their state is validated.

## Implementation Plan

1. Extend the rollout skill and delivery reference with capture, refresh,
   installed validation, and failure handling.
2. Reuse installer selection/mapping/ownership helpers; add a minimal persisted
   selection/readiness contract if existing metadata cannot represent selection.
3. Update downstream setup guidance to distinguish template sync, refresh, and
   consented first-time activation.
4. Add consumer fixture tests and update the rollout skill evaluation. Regenerate
   the asset manifest when distributed assets change.

## Verification

Cover an installed reusable-only consumer, targeted template workflow installs,
a complete ship-it install, staged-only sync, a partial ship-it install,
consumer-owned collisions, malformed selection, unsupported mappings, failed
sync/installer/validation, same-version stale workflows, and an idempotent rerun.
Assert that no unselected class is enabled and no local governance is overwritten.

Use the existing downstream-workflow, sync, rollout evaluation, and payload
dependency tests; run `pwsh tests/run-tests.ps1` for the final implementation.
Validate emitted workflows and installed payloads inside fixture consumer repos,
not only the upstream source tree. No application server, database, or browser
is needed for this filesystem/installer contract.

## Rollout, Observability, and Risks

Release the enhanced procedure through the normal asset distribution path.
Pilot it on an existing managed install and a staged-only consumer before broad
rollout. Report selected/refreshed workflow counts and blockers in upgrade PR
validation evidence.

Rollback through a normal consumer revert PR to its prior pin and installation
selection; restore the previously committed active workflow files as well as
runtime assets. Do not downgrade by copying old runtime over new workflows.

Legacy consumers may lack durable selection/ownership evidence. Fail closed or
request an explicit selection for these consumers instead of inferring a new
class. Keep the implementation split into reviewable PRs if it exceeds the
repository batch guideline.

## Acceptance Criteria

- [ ] Refresh captures selection before sync and reuses the existing installer.
- [ ] No previously unselected automation is enabled without explicit consent.
- [ ] Partial/staged-only/installed states have distinct actionable reports.
- [ ] Installed validation gates commit, push, and upgrade PR creation.
- [ ] Consumer-owned workflows, governance, and profile are preserved.
- [ ] Positive and negative fixture cases pass, including idempotent refresh.
- [ ] Implementation PRs reference this spec and contain validation evidence.

## References

- PRD: `docs/prd/synthesized/issue-3465-consumer-rollout-refresh-omits-downstream-workflow-onboardin.prd.md`
- Refs #3465
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3465>
