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
    $env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
    .\sync.ps1

    # Sync a specific version tag
    $env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
    $env:BASECOAT_REF  = 'v4.0.0'
    .\sync.ps1

    # Sync to a custom target directory
    $env:BASECOAT_REPO       = 'https://github.com/YOUR-ORG/basecoat.git'
    $env:BASECOAT_TARGET_DIR = '.github/my-basecoat'
    .\sync.ps1
    ```

=== "Shell"

    ```bash
    # Sync latest release (from main)
    BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git ./sync.sh

    # Sync a specific version tag
    BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git \
    BASECOAT_REF=v4.0.0 ./sync.sh

    # Sync to a custom target directory
    BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git \
    BASECOAT_TARGET_DIR=.github/my-basecoat ./sync.sh
    ```

## Scoped sync patterns

For consumers that only need part of BaseCoat, use `.basecoat.yml` allow-lists
instead of syncing the full catalog.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: v4.0.0

agents:
  - code-review
  - security-review

skills:
  - harden
  - azure-diagnostics

instructions:
  - governance
  - security-baseline

sync:
  exclude:
    - archive/
```

This keeps updates scoped and auditable because every synced category is declared
in source control. For full key reference and more examples, see
[BaseCoat Config (.basecoat.yml)](basecoat-yml.md).

## Quick refresh shortcut

In Copilot-enabled environments, use the phrase `refresh basecoat` to trigger
the rollout workflow.

The rollout runs the sync inside an isolated worktree and completes the full
delivery lifecycle — branch, sync, commit, push, PR, then worktree cleanup — so
the upgrade never lands as uncommitted changes in your primary working tree. See
[Auditability: capture a sync trail](#auditability-capture-a-sync-trail) for the
before/after evidence to include in the PR.

If your environment reports `Skill not found: rollout-basecoat`, run sync
directly from the consumer repo root:

=== "PowerShell fallback"

    ```powershell
    $env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
    $env:BASECOAT_REF  = 'main'  # or vX.Y.Z
    .\sync.ps1
    ```

=== "Shell fallback"

    ```bash
    BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git \
    BASECOAT_REF=main ./sync.sh
    ```

Even in the fallback path, run the sync inside an isolated worktree and complete
the same commit → push → PR → cleanup lifecycle so the primary working tree is
never left dirty. The `refresh basecoat` skill automates this; when running sync
by hand, follow the [auditability trail](#auditability-capture-a-sync-trail) and
open a PR from a dedicated branch.

## Checking your version

```bash
cat .github/base-coat/version.json
```

## Auditability: capture a sync trail

Record before/after evidence in each consumer upgrade PR so overrides and drift
are reviewable.

=== "PowerShell"

    ```powershell
    # 1) Record current synced version
    Get-Content .github/base-coat/version.json

    # 2) Run scoped sync (uses .basecoat.yml allow-lists when present)
    $env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
    .\sync.ps1

    # 3) Save an auditable patch for reviewer traceability
    New-Item -ItemType Directory -Force -Path .github\base-coat-audit | Out-Null
    git --no-pager diff -- .github/base-coat |
      Set-Content ".github\base-coat-audit\sync-$((Get-Date).ToString('yyyy-MM-dd')).diff"
    git --no-pager diff --stat -- .github/base-coat
    ```

=== "Shell"

    ```bash
    # 1) Record current synced version
    cat .github/base-coat/version.json

    # 2) Run scoped sync (uses .basecoat.yml allow-lists when present)
    BASECOAT_REPO=https://github.com/YOUR-ORG/basecoat.git ./sync.sh

    # 3) Save an auditable patch for reviewer traceability
    mkdir -p .github/base-coat-audit
    git --no-pager diff -- .github/base-coat > ".github/base-coat-audit/sync-$(date +%F).diff"
    git --no-pager diff --stat -- .github/base-coat
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
- [Version Drift Detection](version-drift.md) — N-version alerting policy and automated drift issues
- [Make It Your Own](customization.md) — customization levels from zero-config to full fork
