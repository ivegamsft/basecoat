# Distribution and Packaging

## Overview

Base Coat is packaged and distributed to consuming repositories through multiple methods, enabling teams to incorporate governance agents and instructions based on their integration preferences and workflow requirements.

## Consumption Methods

### Git Submodule (Recommended)

Git submodules provide version-pinned, dependency-aware integration of Base Coat into consuming repositories.

#### Adding as a Submodule

```bash
git submodule add https://github.com/IBuySpy-Shared/basecoat.git .github/basecoat
git submodule update --init --recursive
```

This adds basecoat to `.github/basecoat/` with a reference in `.gitmodules`.

#### Pinning to a Version Tag

To pin to a specific release tag, update the submodule reference:

```bash
cd .github/basecoat
git checkout v1.0.0
cd ../..
git add .github/basecoat .gitmodules
git commit -m "chore: pin basecoat to v1.0.0"
```

Or use `git config`:

```bash
git config -f .gitmodules submodule.basecoat.branch refs/tags/v1.0.0
git submodule update --remote
```

#### Updating to a New Version

```bash
cd .github/basecoat
git fetch origin
git checkout v1.1.0
cd ../..
git add .github/basecoat
git commit -m "chore: update basecoat to v1.1.0"
git push
```

#### .gitmodules Configuration

The `.gitmodules` file tracks submodule references:

```ini
[submodule ".github/basecoat"]
  path = .github/basecoat
  url = https://github.com/IBuySpy-Shared/basecoat.git
  branch = main
```

For a pinned tag, use `branch = refs/tags/v1.0.0`.

### Direct Copy via Sync Scripts

Base Coat provides `sync.ps1` (PowerShell) and `sync.sh` (Bash) scripts for flexible, selective synchronization without Git submodule overhead.

**Important:** Always use the sync scripts to upgrade BaseCoat assets. Do not manually copy files or create PRs that add new agent files — the sync script performs a complete remove-and-replace of the `agents/`, `instructions/`, `skills/`, and `prompts/` directories, ensuring stale files from previous naming conventions are removed. Manual PRs that only add new files without removing old ones will produce a mixed state that the `check-version.yml` workflow will detect and flag.

#### Using sync.ps1 (Windows/PowerShell)

```powershell
.\sync.ps1 -SourceRepo "https://github.com/IBuySpy-Shared/basecoat.git" -DestinationPath ".github/basecoat" -Version "v1.0.0"
```

Copies the specified version of basecoat to the destination path.

#### Using sync.sh (macOS/Linux)

```bash
bash sync.sh --source-repo https://github.com/IBuySpy-Shared/basecoat.git --destination-path .github/basecoat --version v1.0.0
```

#### Selective Sync

Both scripts support filtering by component:

```powershell
.\sync.ps1 -DestinationPath ".github/basecoat" -Components "agents" -Version "v1.0.0"
```

```bash
bash sync.sh --destination-path .github/basecoat --components "agents" --version v1.0.0
```

Supported components: `agents`, `instructions`, `templates`, `config`.

### Release Artifacts

Base Coat publishes versioned artifacts via GitHub Releases.

#### Downloading Release Archives

```bash
# Download ZIP
curl -L https://github.com/IBuySpy-Shared/basecoat/releases/download/v1.0.0/basecoat-v1.0.0.zip -o basecoat.zip

# Download tar.gz
curl -L https://github.com/IBuySpy-Shared/basecoat/releases/download/v1.0.0/basecoat-v1.0.0.tar.gz -o basecoat.tar.gz
```

Extract to your desired location:

```bash
unzip basecoat.zip -d .github/basecoat
# or
tar -xzf basecoat.tar.gz -C .github/basecoat
```

#### SHA256 Verification

Each release includes a `SHA256SUMS` file for integrity verification:

```bash
curl -L https://github.com/IBuySpy-Shared/basecoat/releases/download/v1.0.0/SHA256SUMS -o SHA256SUMS
sha256sum -c SHA256SUMS
```

### npm Package (Future)

Future releases will include an npm package for convenient synchronization via `npx`:

```bash
npx @ibuyspi-shared/basecoat-sync --destination .github/basecoat --version latest
```

Planned features:

- Automatic dependency resolution
- Global installation for CLI access
- Version constraint support (e.g., `~1.0.0`, `^1.0.0`)
- Plugin ecosystem for custom sync strategies

## Version Pinning

### Using version.json

Base Coat includes a `version.json` file containing build metadata and version information:

```json
{
  "version": "1.0.0",
  "buildDate": "2024-01-15T10:30:00Z",
  "repository": "https://github.com/IBuySpy-Shared/basecoat",
  "changelogUrl": "../CHANGELOG.md"
}
```

Consuming projects should track this version in their own metadata.

### Tag-Based Pinning for Submodules

Git tag naming convention: `v<MAJOR>.<MINOR>.<PATCH>`

```bash
# List available tags
git ls-remote --tags https://github.com/IBuySpy-Shared/basecoat.git | grep refs/tags

# Pin to a specific tag
git config -f .gitmodules submodule.basecoat.branch refs/tags/v1.0.0
git submodule update --remote
```

### CHANGELOG for Upgrade Notes

Review `CHANGELOG.md` before upgrading to understand breaking changes, new features, and deprecations:

```bash
# View changes between versions
git log v0.9.0..v1.0.0 --oneline
```

## Selective Installation

### Component-Based Filtering

Install only the agents and instructions you need:

```powershell
# PowerShell: Copy only agents
.\sync.ps1 -DestinationPath ".github/basecoat" -Components "agents"
```

```bash
# Bash: Copy only instructions
bash sync.sh --destination-path .github/basecoat --components "instructions"
```

### Category and Wave Filtering

Base Coat organizes agents and instructions by category and wave. Filter during sync:

```powershell
.\sync.ps1 -DestinationPath ".github/basecoat" -Category "governance" -Wave "1"
```

### Custom Sync Configuration

Create a `.basecoat-sync.json` to define reusable sync profiles:

```json
{
  "profiles": {
    "minimal": {
      "components": ["agents"],
      "categories": ["security"],
      "excludeWaves": ["3", "4"]
    },
    "full": {
      "components": ["agents", "instructions", "templates"],
      "categories": "*"
    }
  }
}
```

Then sync with a profile:

```bash
bash sync.sh --profile minimal
```

## CI Integration

### GitHub Actions Step

Add a workflow step to sync basecoat on pushes or PRs:

```yaml

- name: Sync Base Coat
  uses: IBuySpy-Shared/basecoat/actions/sync@v1
  with:
    destination: .github/basecoat
    version: v1.0.0
    components: agents,instructions
```

Or use the sync scripts directly:

```yaml

- name: Sync Base Coat (PowerShell)
  shell: powershell
  run: |
    Invoke-WebRequest -Uri "https://github.com/IBuySpy-Shared/basecoat/releases/download/v1.0.0/sync.ps1" -OutFile sync.ps1
    .\sync.ps1 -DestinationPath ".github/basecoat" -Version "v1.0.0"
```

### Pre-Commit Hook for Version Checking

Add to `.git/hooks/pre-commit` to verify basecoat version consistency:

```bash
#!/bin/bash
if [ -f ".github/basecoat/version.json" ]; then
  CURRENT_VERSION=$(jq -r '.version' .github/basecoat/version.json)
  echo "✓ Base Coat version: $CURRENT_VERSION"
else
  echo "✗ Base Coat not found in .github/basecoat"
  exit 1
fi
```

Make executable: `chmod +x .git/hooks/pre-commit`

### Automated PR for Updates

Use a scheduled workflow to periodically check for basecoat updates:

```yaml
name: Update Base Coat

on:
  schedule:

    - cron: '0 9 * * 1' # Weekly on Monday at 9 AM UTC

jobs:
  update:
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@v4
      - name: Check for new version
        run: |
          LATEST=$(git ls-remote --tags https://github.com/IBuySpy-Shared/basecoat.git | grep -oP 'v\d+\.\d+\.\d+' | sort -V | tail -1)
          CURRENT=$(jq -r '.version' .github/basecoat/version.json)
          echo "LATEST=$LATEST" >> $GITHUB_ENV
          echo "CURRENT=$CURRENT" >> $GITHUB_ENV

      - name: Create PR if update available
        if: env.LATEST != env.CURRENT
        run: |
          git checkout -b chore/basecoat-update
          ./sync.sh --version ${{ env.LATEST }}
          git add .github/basecoat
          git commit -m "chore: update basecoat to ${{ env.LATEST }}"
          git push origin chore/basecoat-update
          gh pr create --title "chore: update basecoat to ${{ env.LATEST }}" --body "Automated update from ${{ env.CURRENT }} to ${{ env.LATEST }}"
```

## Distributed Workflows (NEW - v3.10.0)

### Overview

Base Coat distributes proven GitHub Actions workflows to consumers, enabling standardized DevOps patterns without reinvention.

### Generic Workflows (9 Total)

Nine production-tested workflows with **zero BaseCoat dependencies**:

| Workflow | Purpose | Setup Time |
|----------|---------|-----------|
| **asset-health.yml** | Asset quality scoring | 1 min |
| **check-version.yml** | Version consistency checks | 1 min |
| **dependency-update-advisor.yml** | Dependency security advisory | 1 min |
| **prd-spec-gate.yml** | Documentation enforcement | 2 min |
| **secret-scan.yml** | Credential detection | 1 min |
| **sprint-closeout-branch-audit.yml** | Branch cleanup & hygiene | 2 min |
| **sync-test.yml** | Sync validation | 1 min |
| **template-validation.yml** | Template structure validation | 1 min |
| **version-check.yml** | Version alignment | 1 min |

### Installation

Workflows are automatically distributed to `.github/base-coat/workflows/` via sync scripts:

```powershell
# PowerShell
.\sync.ps1 -DestinationPath ".github/base-coat" -Version "v3.10.0"
```

```bash
# Bash
bash sync.sh --destination-path .github/base-coat --version v3.10.0
```

Or manually copy:

```bash
cp -r .github/base-coat/workflows/* .github/workflows/
```

### Usage

Each workflow can be triggered manually or on schedule:

```bash
# Run workflow manually
gh workflow run asset-health.yml

# View results
gh run list --workflow asset-health.yml
```

### Customization

Many workflows accept inputs for customization:

```bash
# Run with custom parameters
gh workflow run sprint-closeout-branch-audit.yml \
  --field stale_days=14 \
  --field apply_changes=true
```

### For More Information

- **Getting Started:** See `docs/guides/workflows-getting-started.md`
- **Detailed Reference:** See `docs/guides/workflows-reference.md`
- **Examples:** See `docs/examples/workflow-setups/`
