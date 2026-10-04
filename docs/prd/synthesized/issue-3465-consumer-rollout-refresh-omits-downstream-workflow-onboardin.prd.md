---
issue: 3465
title: "Consumer rollout refresh omits downstream workflow onboarding and installed validation"
status: draft
author: ibuyspy
created: 2026-10-03
labels: ["enhancement", "needs-prd", "synthesize-spec"]
---

# PRD: Consumer rollout refresh omits downstream workflow onboarding and installed validation

## Problem Statement

The official v4.5.2 rollout-basecoat skill resolves .basecoat.yml sync.script and runs only the sync entrypoint before committing the consumer upgrade. Root sync refreshes managed workflow sources and runtime scripts, while active .github/workflows files require configure-downstream-workflows.ps1 separately. Existing consumers can therefore receive new runtime scripts while their active workflows remain stale. Please define and implement an official refresh/onboard contract that preserves selected install classes, runs downstream onboarding, and validates the installed payload before delivery. Affected assets: skills/rollout-basecoat/SKILL.md and the consumer update path. Consumers currently need both official steps documented explicitly. This is an issue-only report; no upstream implementation requested or included.

## Why This Matters

An upgrade can report success while active workflows still execute an older
contract against newly synchronized runtime scripts. Staged workflow sources
are not active GitHub Actions workflows. Consumers need observable readiness
without enabling previously unselected automation or replacing local policy.

## Scope

- Extend the official refresh procedure to snapshot installed workflow selection
  before sync, refresh that selection after sync, and validate installed assets.
- Distinguish staged-only, partially installed, and installed workflow states.
- Preserve consumer-owned workflows, governance, profile, and overlay ownership.
- Include the activation-status follow-up consolidated from duplicate #3474.
- Exclude automatic first-time activation, new approval semantics, cross-repo
  delivery, and changes to other products' overlay ownership.

## Success Criteria

- [ ] Existing installed workflows refresh using the new managed sources.
- [ ] Sync alone does not silently enable additional workflow classes.
- [ ] A staged-only consumer receives an explicit activation command.
- [ ] Installed validation runs before an upgrade is committed or reported ready.
- [ ] Failures remain visible; failed upgrades are not published as successful PRs.
- [ ] Consumer-owned files and policy choices survive an idempotent second run.

## References

- Refs #3465
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3465>
