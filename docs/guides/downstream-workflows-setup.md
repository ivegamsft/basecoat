# Downstream Workflows Setup Guide

This guide explains how consumer repositories install and manage BaseCoat workflows
using the installed `.github/base-coat/scripts/configure-downstream-workflows.ps1`
entrypoint. A BaseCoat source/release checkout also has the root
`scripts/configure-downstream-workflows.ps1`; synced consumers must not assume
that root copy or root bootstrap scripts exist.

For cross-repo detection/escalation of reviewer-routing failures, see
`docs/guides/downstream-reviewer-routing-audit.md`.

## Naming model

Installed workflows use explicit BaseCoat provenance:

- `basecoat-<capability>.yml` for reusable workflows
- `basecoat-agent-<capability>.yml` for advanced agent templates
- `basecoat-internal-<capability>.yml` for internal workflows

Legacy `bc-*` names are treated as migration targets and are removed when the
new canonical filenames are installed.

## Installation classes

The installer supports five classes:

1. `reusable` (default)
2. `ship-it` (default) — active, event-triggered ship-it delivery workflows
   (`ship-it-intent-dispatch.yml`, `ship-it-build-guard.yml`,
   `ship-it-release-gate.yml`); the skill's fail-closed contract requires
   all three to be installed together or not at all, so this class
   installs by default (see issue #2943).
3. `onboarding-telemetry` (opt-in via `-InstallClass`) — autonomous,
   scheduled, write-permission workflow (`adoption-metrics.yml`)
4. `templates` (opt-in)
5. `internal` (opt-in)

By default, `reusable` and `ship-it` workflows are installed.

## Refresh after a BaseCoat sync

Syncing refreshes the staged payload; it does not by itself update active
`.github/workflows` files. For an existing installation, capture the exact
factory-owned workflow selection before sync, then pass those targets to the
installer after sync. This refreshes active BaseCoat workflows without enabling
new templates or overwriting consumer-owned workflows:

```powershell
$Selection = pwsh .github/base-coat/scripts/invoke-basecoat-consumer-update.ps1 `
  -CaptureWorkflowSelection -StagePath .github/base-coat | ConvertFrom-Json
if ($Selection.state -eq 'partial') {
  throw "Partial ship-it install; missing: $($Selection.missing_dependencies -join ', ')"
}

# Run your normal sync command here.

if ($Selection.workflow_targets.Count -gt 0) {
  pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 `
    -SourceDir .github/base-coat/workflows `
    -DestinationDir .github/workflows `
    -Workflow $Selection.workflow_targets
}
pwsh .github/base-coat/scripts/validate-basecoat.ps1 `
  -RootDir .github/base-coat `
  -WorkflowValidationMode Consumer `
  -ConsumerRoot .
```

If the selection is `staged-only`, do not install defaults as part of refresh.
For a deliberate first activation, inspect the workflow permissions and triggers,
then run the explicit activation command printed by the selection tool. This
changes repository workflow files only; GitHub Actions settings, secrets, and
credentials remain unchanged. Missing ownership evidence, a partial ship-it
installation, or a failed install/validation blocks delivery.

## Onboarding prerequisites

Before installing workflows in a consumer repository, run the BaseCoat
bootstrap script and select the governance profile for that repo. For
single-maintainer repositories, follow the
[Solo-Developer Governance Profile](solo-dev-profile.md); for team-owned repos,
use the profile selected by `.github/basecoat-onboarding-profile.json`.

Root `scripts/bootstrap.ps1` and `scripts/bootstrap-basecoat.ps1` are
source/release bootstrap tools, not content-sync payloads. Obtain them through
the [supported setup flow](../getting-started.md) for first-time onboarding.
For an already onboarded consumer, use the selection-preserving refresh above;
do not install default workflow classes merely to replace missing bootstrap
files. Sync does not apply GitHub governance settings.

Keep the repository default workflow permission set to **Read repository
contents and packages permissions**. Workflows that need write access declare
their own `permissions:` blocks. If a selected workflow creates pull requests
with `GITHUB_TOKEN` (for example `issue-to-spec-synthesis.yml`), review the
separate **Allow GitHub Actions to create and approve pull requests** platform
policy. Template installation ships workflow files, governance files, and
bootstrap guidance; it does not ship Enterprise, organization, or repository
Actions settings, secrets, or GitHub App credentials. Use the narrowest safe
policy path: avoid Enterprise-wide global enablement for one consumer repo,
prefer org-level override/restriction where available, then repo-level opt-in
where available, then a temporary scoped `GH_AW_GITHUB_TOKEN`. A GitHub App or
brokered token is the preferred durable fix when the platform toggle cannot be
narrowed safely.

## Quick start

For deliberate first activation, run from the synced consumer repository root.
Preview the selected classes with `-DryRun` and review their triggers/permissions
before installing. For an existing installation, use the refresh procedure
above instead of reinstalling defaults:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows
```

Default install (reusable + ship-it classes) includes:

```text
.github/workflows/
├── basecoat-upstream-version-drift.yml
├── basecoat-version-check.yml
├── basecoat-secret-scan.yml
├── ship-it-intent-dispatch.yml
├── ship-it-build-guard.yml
└── ship-it-release-gate.yml
```

To install only the reusable class (skip ship-it):

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows -InstallClass reusable
```

## Include templates and internal workflows

Install reusable + templates:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows -IncludeTemplates
```

Install reusable + templates + internal:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows -IncludeTemplates -IncludeInternal -IncludeUnsupported
```

Install reusable, ship-it, templates, and internal workflows, including
advanced/unsupported workflows. Onboarding telemetry (`adoption-metrics.yml`) is
a separate opt-in class and is not included:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows -IncludeTemplates -IncludeInternal -IncludeUnsupported
```

## Dry-run mode

Preview without changing files:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir .github/base-coat/workflows -DestinationDir .github/workflows -DryRun
```

## Migration notes

The installer now uses canonical `basecoat-*` naming and removes legacy files
when replacements are installed. Current legacy mappings:

| Legacy filename | Canonical filename |
| --- | --- |
| `bc-check-health.yml` | `basecoat-upstream-version-drift.yml` |
| `bc-version-check.yml` | `basecoat-version-check.yml` |
| `bc-secret-scan.yml` | `basecoat-secret-scan.yml` |
| `bc-dependency-update-advisor.yml` | `basecoat-dependency-update-advisor.yml` |
| `bc-sprint-closeout-branch-audit.yml` | `basecoat-sprint-closeout-branch-audit.yml` |

## Common commands

```bash
# List installed BaseCoat workflows
ls .github/workflows/ | grep basecoat-

# Trigger secret scan manually
gh workflow run basecoat-secret-scan.yml

# Trigger version check manually
gh workflow run basecoat-version-check.yml

# Watch runs
gh run list --workflow basecoat-version-check.yml
```

## Troubleshooting

### Source workflow directory not found

The installer expects `.github/base-coat/workflows/` by default. Run your BaseCoat
sync flow first. If your sync stages to a different path, pass that custom source
directory:

```bash
pwsh .github/base-coat/scripts/configure-downstream-workflows.ps1 -SourceDir ".github/base-coat/workflows" -DestinationDir ".github/workflows"
# or, if your sync process stages elsewhere:
pwsh .github/basecoat-sync/scripts/configure-downstream-workflows.ps1 -SourceDir ".github/basecoat-sync/workflows" -DestinationDir ".github/workflows"
```

### Unmarked workflows were preserved

BaseCoat only retires workflows explicitly marked `factory-owned` in
`.github/base-coat/workflows/workflow-ownership-manifest.json`. Unmarked files
are repository-owned by default, even if their filename has a managed prefix.

Use the guarded retirement command only after completing the
[offboarding checklist](downstream-workflow-offboarding.md):

```powershell
pwsh .github/base-coat/scripts/retire-downstream-workflows.ps1 `
  -Workflow basecoat-secret-scan.yml -DryRun
```
