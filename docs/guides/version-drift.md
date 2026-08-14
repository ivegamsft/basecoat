# Version Drift Detection

BaseCoat provides a callable workflow that consumer repos can schedule to detect when their synced assets are out of date.
Release-version drift remains the default signal, with optional asset-level drift available via
`asset-manifest.json` and the adoption scanner.

## Prerequisites

The callable is a reusable workflow hosted in the BaseCoat repository. Before consumers can call it:

- **Actions sharing must be enabled.** In the BaseCoat repository, set
  *Settings → Actions → General → Access* to **Accessible from repositories in the organization**
  (or a broader scope). If sharing is `none`, downstream runs fail at startup with
  `error parsing called workflow ... workflow was not found`, even though the file exists.
- **Private/internal sources need a fetch token.** The default `GITHUB_TOKEN` cannot read releases
  across repositories. When BaseCoat is private or internal, pass a `fetch_token` secret with
  release read access (see the private-source example below). Without it the run **fails closed**
  with an explicit error rather than silently reporting no drift.

## How it works

```mermaid
sequenceDiagram
    participant CR as Consumer Repo
    participant GH as GitHub Actions
    participant BC as BaseCoat Releases
    CR->>GH: Scheduled trigger (weekly)
    GH->>CR: Read .github/base-coat/version.json
    GH->>BC: Fetch latest release tag
    GH->>GH: Compute release version drift
    alt drift >= threshold
        GH->>CR: Open/update upgrade issue
    else up to date
        GH->>GH: No action
    end
```

## Setup

Copy this to `.github/workflows/check-basecoat-version.yml` in your consumer repo:

```yaml
name: Check BaseCoat Version
on:
  schedule:
    - cron: '0 9 * * 1'
  workflow_dispatch:
jobs:
  check:
    uses: YOUR-ORG/basecoat/.github/workflows/check-basecoat-version-callable.yml@main
    with:
      stage_path: .github/base-coat
      alert_threshold: 1
      source_repo: YOUR-ORG/basecoat
    permissions:
      issues: write
      contents: read
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `stage_path` | `.github/base-coat` | Path to synced BaseCoat assets |
| `alert_threshold` | `1` | Versions behind before alerting |
| `source_repo` | Required | Source BaseCoat repository in `owner/repo` format |

### Secrets

| Secret | Required | Description |
|---|---|---|
| `fetch_token` | Only for private/internal sources | Token with read access to the source repository's releases. Omit for public sources (the default `GITHUB_TOKEN` is used). |

### Private or internal source

When the source BaseCoat repository is private or internal, pass a `fetch_token` secret:

```yaml
jobs:
  check:
    uses: YOUR-ORG/basecoat/.github/workflows/check-basecoat-version-callable.yml@main
    with:
      stage_path: .github/base-coat
      alert_threshold: 1
      source_repo: YOUR-ORG/basecoat
    secrets:
      fetch_token: ${{ secrets.BASECOAT_REPO_TOKEN }}
    permissions:
      issues: write
      contents: read
```

## Choosing an alert threshold (N versions)

Set `alert_threshold` to match your upgrade policy:

| Policy | `alert_threshold` | Expected behavior |
|---|---:|---|
| Strict | `0` | Alert as soon as any version drift is detected |
| Recommended | `1` | Alert when at least one version behind |
| Relaxed | `2` | Alert only when two or more versions behind |

Example (recommended baseline):

```yaml
jobs:
  check:
    uses: YOUR-ORG/basecoat/.github/workflows/check-basecoat-version-callable.yml@main
    with:
      stage_path: .github/base-coat
      alert_threshold: 1
      source_repo: YOUR-ORG/basecoat
```

## What the issue looks like

When drift is detected, an issue is opened in the consumer repo titled:

> `chore: BaseCoat upgrade available (v4.0.0 → v4.1.0)`

The issue includes the current version, latest version, and upgrade instructions. If the issue already exists, a comment is added instead (idempotent).

## Auditability and evidence

For an auditable version-alignment trail in consumer repos:

1. Keep the callable workflow on a schedule (weekly is a common baseline).
2. Preserve the generated drift issue(s) instead of deleting/recreating them.
3. Link each upgrade PR to the corresponding drift issue.

You can trace drift checks with:

```bash
gh run list --workflow check-basecoat-version.yml --limit 10
gh issue list --search "BaseCoat upgrade available" --state all
```

## Asset-level drift (optional)

To evaluate per-asset version/SHA drift across consumer repos:

```powershell
pwsh scripts/adoption/detect-basecoat.ps1 -Org YOUR-ORG -OutputFormat markdown -AssetDetail
```

When a source asset has frontmatter `version`, the scanner compares source vs consumer version.
When version metadata is unavailable, it falls back to SHA drift comparison.
