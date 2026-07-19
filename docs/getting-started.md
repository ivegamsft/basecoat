# Getting Started

Get BaseCoat assets into your repo in under 5 minutes.

## Prerequisites

- GitHub repo with Copilot enabled
- `gh` CLI or direct repo access

## Option 1: Automated sync (recommended)

Run the sync script in your repo root:

=== "PowerShell (Windows)"

    ```powershell
    $sourceRepo = "YOUR-ORG/basecoat"
    $tag = (gh release list --repo $sourceRepo --limit 1 --json tagName -q '.[0].tagName')
    $version = $tag.TrimStart('v')
    $url = "https://github.com/$sourceRepo/releases/download/$tag/base-coat-$version.zip"
    Invoke-WebRequest $url -OutFile base-coat.zip
    Expand-Archive base-coat.zip -DestinationPath .github/base-coat -Force
    Remove-Item base-coat.zip
    ```

=== "Shell (Linux/macOS)"

    ```bash
    curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.sh | bash
    ```

After syncing, your repo will have a `.github/base-coat/` directory containing all BaseCoat assets.

## Option 2: Manual setup

1. Go to the latest release page for your source repository (`https://github.com/YOUR-ORG/basecoat/releases/latest`)
2. Download `base-coat-<version>.zip`
3. Extract to `.github/base-coat/` in your repo
4. Commit the result

## Verify your sync

Check the version installed:

```bash
cat .github/base-coat/version.json
```

## Keep it up to date

Add the version drift detector to your repo — it opens an issue automatically when BaseCoat has a new release:

```yaml
# .github/workflows/check-basecoat-version.yml
name: Check BaseCoat Version
on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly Monday 09:00 UTC
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

## Next steps

- [Enterprise setup](guides/enterprise-setup.md) — reduced-friction setup for organization members
- [Onboarding profile contract](reference/onboarding-profile-contract.v1.md) — versioned profile posture and migration rules
- [Asset reference](reference/quick-reference.md) — browse all available agents, skills, and instructions
- [Contributing](guides/contributing.md) — add your own patterns back to BaseCoat
