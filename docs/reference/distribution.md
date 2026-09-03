# Distribution and Packaging

## Overview

BaseCoat can be consumed as a Git submodule, by running the repository's sync
scripts, by downloading a release artifact, or by template-based bootstrapping.
The sync scripts are the supported way to replace managed assets without leaving
stale agents, instructions, skills, prompts, or workflows.

## Git Submodule

Add BaseCoat as a version-pinned submodule:

```bash
git submodule add https://github.com/IBuySpy-Shared/basecoat.git .github/base-coat
git submodule update --init --recursive
```

To use a release tag, check out the desired tag in the submodule and commit the
resulting submodule pointer:

```bash
cd .github/base-coat
git checkout v4.2.1
cd ../..
git add .github/base-coat .gitmodules
git commit -m "chore: pin basecoat to v4.2.1"
```

The submodule keeps the source assets available under `.github/base-coat`; it
does not install Copilot-discoverable files. Run the sync scripts or the
relevant installer after updating the submodule to populate consumer paths.

## Sync Scripts

`sync.ps1` and `sync.sh` install BaseCoat into `.github/base-coat` by default.
They resolve their source and ref in this order:

1. `BASECOAT_REPO` and `BASECOAT_REF` environment variables.
2. Top-level `source` and `ref` entries in the repository-root `.basecoat.yml`.
3. The built-in placeholder repository and the `main` ref.

`BASECOAT_MIRROR` selects an immutable corporate mirror for fetching, and
`BASECOAT_TARGET_DIR` overrides the destination directory. A
`known_bad_releases` mapping in `.basecoat.yml` can redirect an unsafe ref to
its supported replacement.

For example:

```powershell
$env:BASECOAT_REPO = "https://github.com/IBuySpy-Shared/basecoat.git"
$env:BASECOAT_REF = "v4.2.1"
.\sync.ps1
```

```bash
BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git \
BASECOAT_REF=v4.2.1 \
bash sync.sh
```

The scripts replace managed directories in place. An interrupted run can leave
a mixed old/new installation; rerun the sync to the same ref before continuing.
Do not manually copy individual managed assets as an upgrade strategy.

## Version Metadata

The current `version.json` shape is:

```json
{
  "name": "base-coat",
  "version": "4.2.1",
  "releaseDate": "2026-08-31",
  "notes": "Release summary"
}
```

Read `CHANGELOG.md` before upgrading to understand release-specific changes.

## Distributed Workflows

BaseCoat workflow sources are stored in `.github/base-coat/workflows`. Use
`scripts/configure-downstream-workflows.ps1` to select and install supported
workflow classes into a consumer repository's `.github/workflows` directory.
The installer is authoritative for both the available classes and the source to
destination filename mappings.

The default classes are `reusable` and `ship-it`. `templates`, `internal`, and
`onboarding-telemetry` are opt-in; onboarding telemetry is selected explicitly
with `-InstallClass onboarding-telemetry`. To inspect installation changes
without writing files:

```powershell
pwsh scripts/configure-downstream-workflows.ps1 -DryRun
```

The distributed `workflow-ownership-manifest.json` marks the workflows that
BaseCoat may retire. All workflows not explicitly marked `factory-owned` are
repository-owned and preserved. See the
[Downstream Workflow Offboarding Checklist](../guides/downstream-workflow-offboarding.md)
before retiring a factory workflow.

`version-check.yml` validates this repository's version metadata. Consumer
workflow filenames can use `basecoat-*` names because those are the installer
destinations, not necessarily the workflow source filenames.

For setup and the complete workflow catalog, see:

- `docs/guides/workflows-getting-started.md`
- `docs/guides/workflows-reference.md`
