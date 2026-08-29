# Downstream Workflows Setup Guide

This guide explains how consumer repositories install and manage BaseCoat workflows
using `scripts/configure-downstream-workflows.ps1`.

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

## Quick start

Run from repository root:

```bash
pwsh scripts/configure-downstream-workflows.ps1
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
pwsh scripts/configure-downstream-workflows.ps1 -InstallClass reusable
```

## Include templates and internal workflows

Install reusable + templates:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates
```

Install reusable + templates + internal:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates -IncludeInternal -IncludeUnsupported
```

Install all classes, including advanced/unsupported workflows:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates -IncludeInternal -IncludeUnsupported
```

## Dry-run mode

Preview without changing files:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -DryRun
```

## Migration notes

The installer now uses canonical `basecoat-*` naming and removes legacy files
when replacements are installed. Current legacy mappings:

| Legacy filename | Canonical filename |
|---|---|
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
pwsh scripts/configure-downstream-workflows.ps1 -SourceDir ".github/base-coat/workflows"
# or, if your sync process stages elsewhere:
pwsh scripts/configure-downstream-workflows.ps1 -SourceDir ".github/basecoat-sync/workflows"
```

### Unknown managed workflows were removed

By default, the installer removes unknown files with managed prefixes
(`bc-`, `basecoat-`, `basecoat-agent-`, `basecoat-internal-`).

To keep unknown managed files:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -KeepUnknownBc
```
