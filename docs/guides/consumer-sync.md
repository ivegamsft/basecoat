# Consumer Sync Guide

This guide covers syncing BaseCoat assets into a consumer repository and keeping them up to date.

## What gets synced

The sync script copies all distributable assets to `.github/base-coat/` in your repo:

- `agents/` — all agent definition files
- `skills/` — all skill directories
- `instructions/` — all instruction files
- `prompts/` — prompt templates
- `version.json` — version metadata

Files that are **not** synced: `basecoat-metadata.json` (internal portal index), test scripts, CI workflows, and internal tooling. Selected documentation content is synced under `.github/base-coat/docs/`, but not the full source `docs/` tree.

## Sync commands

=== "PowerShell"

    ```powershell
    # Sync latest release (from main)
    $env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
    .\sync.ps1

    # Sync a specific version tag
    $env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
    $env:BASECOAT_REF  = 'v3.25.0'
    .\sync.ps1

    # Sync to a custom target directory
    $env:BASECOAT_REPO       = 'https://github.com/IBuySpy-Shared/basecoat.git'
    $env:BASECOAT_TARGET_DIR = '.github/my-basecoat'
    .\sync.ps1
    ```

=== "Shell"

    ```bash
    # Sync latest release (from main)
    BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git ./sync.sh

    # Sync a specific version tag
    BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git \
    BASECOAT_REF=v3.25.0 ./sync.sh

    # Sync to a custom target directory
    BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git \
    BASECOAT_TARGET_DIR=.github/my-basecoat ./sync.sh
    ```

## Quick refresh shortcut

In Copilot-enabled environments, use the phrase `refresh basecoat` to trigger
the rollout workflow.

If your environment reports `Skill not found: rollout-basecoat`, run sync
directly from the consumer repo root:

=== "PowerShell fallback"

    ```powershell
    $env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
    $env:BASECOAT_REF  = 'main'  # or vX.Y.Z
    .\sync.ps1
    ```

=== "Shell fallback"

    ```bash
    BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git \
    BASECOAT_REF=main ./sync.sh
    ```

## Checking your version

```bash
cat .github/base-coat/version.json
```

## Automating upgrades

Add the callable drift-detection workflow to get automatic issue notifications when a new BaseCoat version is available. See [Getting Started](../getting-started.md#keep-it-up-to-date).

## Naming convention

BaseCoat uses two names intentionally:

| Name | Used for |
|---|---|
| `basecoat` | GitHub repo, internal scripts, environment variables (`BASECOAT_*`) |
| `base-coat` | Distributed artifact, sync target (`.github/base-coat/`), `version.json`, release archives |

See [ADR-001](../architecture/decisions/adr-001-naming-convention.md) for full details.

## See also

- [BaseCoat Config (.basecoat.yml)](basecoat-yml.md) — full field reference for sync and memory sweep configuration
- [Make It Your Own](customization.md) — customization levels from zero-config to full fork
