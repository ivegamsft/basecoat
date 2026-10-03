---
issue: 3433
title: "configure-downstream-workflows prepends duplicate workflow name keys"
status: in-review
author: ibuyspy
created: 2026-09-19
updated: 2026-10-02
labels: ["bug", "priority:high", "sprint:2026-W40"]
---

# Technical Specification: Downstream Workflow Name Generation

## Context

`scripts/configure-downstream-workflows.ps1` reads each source workflow as raw
text, splits it into lines, and replaces the first line matching a quoted
top-level `name:` key. If that match is not found, it prepends a configured
name. The current call supplies `-1` as the `-split` maximum-substrings
argument. In PowerShell, a negative maximum splits from the end; `-1` returns
the entire input as one element. The anchored name regex then fails to match a
normal multi-line workflow, and the fallback prepends a duplicate key.

GitHub rejects a workflow with duplicate top-level `name` keys. This can block
consumer workflow updates, including workflows that provide the
`BaseCoat merge eligibility` status.

## Scope

- Correct the workflow text line splitting in
  `scripts/configure-downstream-workflows.ps1`.
- Preserve the existing behavior of replacing a recognized top-level name or
  prepending the configured name when none is present.
- Preserve all unrelated workflow content and the existing encoding/newline
  behavior to the extent supported by the current script.
- Add a focused regression test that exercises a source workflow with an
  existing top-level name.
- Validate the generated workflow using an existing repository workflow/YAML
  validation mechanism.

## Out of Scope

- Changing the workflow inventory, destination filenames, or configured
  downstream display names.
- Rewriting unrelated YAML fields or introducing a YAML serializer.
- Changing the merge-eligibility workflow contract or repository rules.
- Bulk repair of downstream repositories.
- Auditing every unrelated `-split` usage outside the downstream configurator.

## Architecture Overview

Keep the current text-based transformation. Split the source content into
individual lines using PowerShell's normal forward split behavior, then use
the existing anchored top-level-name match to replace the first recognized
name. If no name is found, prepend one as today. Join the transformed lines
and write through the existing destination path.

Do not use a negative `-split` maximum as an unlimited-split idiom. If preserving
a trailing empty element is necessary for the current output contract, handle
the trailing newline explicitly rather than changing the split direction.

## Data Model and Storage Changes

None. The change operates on workflow text and does not modify persistent
metadata or formats.

## API and Interface Contracts

The script's parameters, workflow mapping, output paths, and configured display
names remain unchanged.

For each configured source workflow:

1. If a top-level `name:` line is recognized, replace it with the configured
   display name.
2. If no top-level `name:` line is recognized, prepend the configured display
   name.
3. Emit exactly one top-level `name:` key.
4. Preserve all non-name workflow content.

The regression test must cover an existing name and verify the replacement,
key count, and syntax validity. Existing behavior for a source without a name
must remain covered by the surrounding test suite or an adjacent case.

## Security and Privacy Considerations

No new inputs, permissions, credentials, or external services are introduced.
The transformation must not evaluate workflow content as PowerShell or alter
permissions, triggers, or job definitions.

## Reliability and Failure Modes

- An incorrect split may cause the replacement match to fail and reintroduce
  the duplicate-key defect.
- Incorrect newline handling may concatenate lines or change the output
  unexpectedly. Regression coverage should include the source line-ending
  format(s) used by the existing fixture corpus.
- Workflow syntax validation must fail the test when duplicate keys make the
  generated document invalid.
- Existing configurator error handling and missing-source behavior are
  unchanged.

## Performance and Capacity Considerations

No material impact. Each workflow is small and is still read, transformed, and
written once.

## Implementation Plan

1. Replace the negative split limit with a normal line split in the workflow
   installation path.
2. Preserve trailing-newline behavior explicitly if the existing test contract
   demonstrates it is required.
3. Add a regression test that invokes the configurator with a workflow already
   containing a top-level name and verifies the output contains only the
   configured name.
4. Run the focused test and repository validation that parses or validates
   generated workflows.

## Testing Strategy

- **Regression:** source fixture includes a top-level `name:`; generated output
  has exactly one top-level name and its value equals the configured name.
- **Fallback:** source fixture has no top-level name; generated output still
  receives the configured name.
- **Content preservation:** compare representative non-name lines before and
  after transformation.
- **Syntax:** run the existing repository workflow/YAML validation against the
  generated file.
- **Regression suite:** run the focused configurator test and the smallest
  repository validation command covering the changed script.
- **Line endings:** include CRLF and/or LF cases consistent with existing
  fixtures to prevent platform-specific behavior.

## Rollout, Migration, and Rollback Plan

No migration is required. The fix takes effect when the configurator is run
again in a consumer repository. If the change causes an unrelated workflow
format regression, revert the focused split/name transformation and retain
the regression fixture while adjusting the implementation.

## Observability and Operational Readiness

The configurator's existing “installed workflow” output remains unchanged.
The regression test and workflow syntax validation are the pre-merge signal;
no new telemetry or runtime logging is required.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Removing the negative split limit changes trailing empty-line handling | Assert the generated newline contract and handle the final newline explicitly if needed |
| Test only checks textual occurrence, not YAML validity | Run the existing workflow/YAML validator on the generated artifact |
| Test fixture bypasses the actual script transformation | Invoke the configurator through the existing test harness |

## Open Questions

- Which existing test helper provides the most direct YAML validation for the generated artifact? Prefer the repository's current validation path; do not add a dependency solely for this test.

## References

- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3433>
- Product requirements:
  `docs/prd/synthesized/issue-3433-configure-downstream-workflows-prepends-duplicate-workflow-n.prd.md`
- Reproduction and expected fix: #3433
