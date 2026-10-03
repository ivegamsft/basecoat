---
issue: 3433
title: "configure-downstream-workflows prepends duplicate workflow name keys"
status: in-review
author: ibuyspy
created: 2026-09-19
updated: 2026-10-02
labels: ["bug", "priority:high", "sprint:2026-W40"]
---

# Product Requirements Document: Downstream Workflow Name Generation

## Problem Statement

`scripts/configure-downstream-workflows.ps1` can produce invalid GitHub Actions
workflow files when it installs a source workflow that already has a top-level
`name:` key. The generated file can contain both the intended downstream name
and the original name, and GitHub rejects the duplicate key. This has blocked
downstream workflow installation and can prevent the merge-eligibility workflow
from reporting its required status.

## Goals

- Generate a downstream workflow with exactly one top-level `name:` key.
- Preserve the configured downstream display name and all other workflow
  content.
- Detect regressions with an automated test using a source workflow that already
  declares a name.

## Non-Goals

- Changing workflow triggers, permissions, jobs, or runtime behavior.
- Renaming workflow files or changing the configured display-name mapping.
- Rewriting or normalizing unrelated YAML content.
- Repairing already-installed downstream repositories as part of this change.

## User Personas and Use Cases

- **BaseCoat maintainer:** installs or refreshes the managed workflow set in a
  consumer repository.
- **Consumer repository maintainer:** receives valid workflow YAML with the
  expected BaseCoat-prefixed name and can use GitHub Actions normally.

## User Experience Summary

Running the downstream workflow configurator replaces the source workflow's
top-level name with its configured consumer-facing name. When the source
workflow has no name, the configurator continues to add one. The result remains
valid YAML and retains the rest of the workflow.

## Functional Requirements

1. The configurator must recognize an existing top-level `name:` line and
   replace it with the configured downstream display name rather than adding a
   second key.
2. If no top-level name exists, the configurator must continue to prepend the
   configured display name.
3. The transformation must preserve the remaining workflow lines and produce
   a file ending with the repository's existing newline convention.
4. Regression coverage must exercise the real configurator with a workflow
   that already declares `name:` and assert exactly one top-level name remains,
   with the configured value.
5. The generated workflow must pass the repository's available workflow/YAML
   validation.

## Non-Functional Requirements

- Keep the change limited to line splitting/name handling and focused tests.
- Do not add a new runtime dependency solely for the regression test.
- Retain compatibility with the PowerShell version supported by the
  configurator.

## Success Metrics

- The regression fixture produces exactly one top-level `name:` key.
- The resulting value equals the configured downstream workflow name.
- The generated workflow passes the repository's workflow syntax validation.
- Existing configurator and repository tests pass.

## Constraints and Assumptions

- Workflow names are top-level YAML keys; indented job or step fields are not
  candidates for replacement.
- The configured display name remains the source of truth for the installed
  workflow name.
- Existing source workflows can contain CRLF or LF line endings.

## Risks and Open Questions

- PowerShell's negative `-split` limit changes split direction rather than
  meaning “unlimited,” so removing that argument must not accidentally change
  expected trailing-newline behavior.
- A text-level regression should validate YAML using an existing repository
  validator where possible, rather than accepting a regex-only approximation.

## Dependencies

- Existing workflow mapping and naming rules in
  `scripts/configure-downstream-workflows.ps1`.
- Existing downstream configurator test and workflow syntax validation
  patterns.

## Rollout and Adoption Plan

Ship the targeted configurator fix and regression test through the normal PR
validation and merge process. No migration is required; rerunning downstream
configuration writes the corrected generated workflow.

## References

- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3433>
- Technical specification:
  `docs/spec/synthesized/issue-3433-configure-downstream-workflows-prepends-duplicate-workflow-n.spec.md`
