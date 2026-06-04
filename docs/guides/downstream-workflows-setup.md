# Downstream Workflows Setup Guide for Consumers

This guide helps consumer repositories (downstream users of BaseCoat) install and configure
the safe subset of BaseCoat workflows into their own GitHub Actions environment.

## What Are Downstream Workflows?

**Downstream workflows** are a subset of BaseCoat's GitHub Actions workflows that have been
validated and packaged for distribution to consumer repositories. They are generic,
self-contained workflows designed to work with minimal configuration in any consumer repo.

### Why the bc- Prefix?

Workflows installed by `configure-downstream-workflows.ps1` use a `bc-` prefix (e.g., `bc-secret-scan.yml`):

- **Avoids naming collisions**: Consumer repos can have their own workflows without conflicts
- **Easy identification**: You can instantly see which workflows come from BaseCoat
- **Safe filtering**: Automation can target BaseCoat workflows specifically
- **Clear separation**: Distinguishes factory-maintained workflows from consumer-specific workflows

### Why Workflows Are Marked "Downstream"

Some BaseCoat workflows are marked as downstream-safe (Phase 1), while others require
consumer-specific setup:

**Downstream-safe (Phase 1)** workflows:

- Require zero configuration
- Have no external dependencies on BaseCoat infrastructure
- Work standalone in any GitHub repository
- Are production-tested in the BaseCoat factory

**Not downstream-safe (Phase 2)** workflows:

- Depend on BaseCoat-specific scripts or tooling
- Require custom environment setup
- Need consumer adaptation before deployment

See [Supported Workflows](#supported-workflows-phase-1) for the complete list.

## How to Install Downstream Workflows

### Quick Start

Run the installation script from your consumer repository root:

```bash
pwsh scripts/configure-downstream-workflows.ps1
```

This installs all Phase 1 downstream-safe workflows with default settings.

### Step-by-Step Installation

1. **Clone or update the BaseCoat distribution package**:

   ```bash
   # BaseCoat syncs workflows into .github/base-coat/workflows/
   # If you're using BaseCoat's sync script, this happens automatically
   pwsh scripts/sync.ps1
   ```

2. **Run the downstream workflow installer**:

   ```bash
   pwsh scripts/configure-downstream-workflows.ps1
   ```

   This copies workflows from `.github/base-coat/workflows/` to `.github/workflows/`
   with the `bc-` prefix and removes any unsupported Phase 2 workflows that may
   already exist.

3. **Verify installation**:

   ```bash
   ls .github/workflows/ | grep bc-
   ```

   You should see:

   ```text
   bc-check-health.yml
   bc-dependency-update-advisor.yml
   bc-prd-spec-gate.yml
   bc-secret-scan.yml
   bc-sprint-closeout-branch-audit.yml
   bc-version-check.yml
   ```

4. **Commit the changes**:

   ```bash
   git add .github/workflows/bc-*.yml
   git commit -m "chore: install BaseCoat downstream workflows"
   git push origin <branch>
   ```

## Supported Workflows (Phase 1)

### 1. bc-check-health.yml

**Purpose**: Automated quality scoring for agents, skills, and instructions.

**Trigger**: Manual or cron-based

**Setup**: No configuration required.

**Use when**: You want to enforce consistent asset quality standards.

---

### 2. bc-version-check.yml

**Purpose**: Validates version consistency across your repository.

**Trigger**: Manual

**Setup**: No configuration required.

**Use when**: You need to verify version.json alignment before releases.

---

### 3. bc-secret-scan.yml

**Purpose**: Prevents accidental commits of hardcoded secrets and credentials.

**Trigger**: On every push and pull request

**Setup**: No configuration required.

**Use when**: You want automated secret detection as a baseline security control.

---

### 4. bc-prd-spec-gate.yml

**Purpose**: Enforces architecture documentation (PRD/spec links) for large changes.

**Trigger**: Automatic on pull requests exceeding size thresholds

**Setup**: Configurable size thresholds (default: 500 lines, 12 files)

**Use when**: You want to require documentation review for significant changes.

**Override**: Add `skip-prd-spec-check` label to bypass for mechanical changes.

---

### 5. bc-dependency-update-advisor.yml

**Purpose**: Security advisory for dependency vulnerabilities.

**Trigger**: Manual or cron-based

**Setup**: Configurable package manager (default: npm)

**Use when**: You want to stay informed of dependency security issues.

---

### 6. bc-sprint-closeout-branch-audit.yml

**Purpose**: Automated cleanup of merged and stale branches.

**Trigger**: Manual or cron-based

**Setup**: Configurable branch age threshold (default: 30 days)

**Use when**: You want to reduce branch clutter and improve navigation.

## Example: Running the Installation Script

### Dry-Run Mode

Preview what the script will do without making changes:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -DryRun
```

**Output**:

```text
INFO: Would copy check-version.yml -> bc-check-health.yml
INFO: Would copy version-check.yml -> bc-version-check.yml
INFO: Would copy secret-scan.yml -> bc-secret-scan.yml
INFO: Would copy prd-spec-gate.yml -> bc-prd-spec-gate.yml
INFO: Would copy dependency-update-advisor.yml -> bc-dependency-update-advisor.yml
INFO: Would copy sprint-closeout-branch-audit.yml -> bc-sprint-closeout-branch-audit.yml
INFO: Skipping unsupported workflow: bc-asset-health.yml
INFO: Skipping unsupported workflow: bc-sync-test.yml
INFO: Skipping unsupported workflow: bc-template-validation.yml

Summary:
  Copied:  6
  Removed: 0
  Skipped: 3
```

### Full Installation

Run the script for real:

```bash
pwsh scripts/configure-downstream-workflows.ps1
```

**Output**:

```text
OK:   Created destination directory: .github/workflows
OK:   Installed workflow: bc-check-health.yml
OK:   Installed workflow: bc-version-check.yml
OK:   Installed workflow: bc-secret-scan.yml
OK:   Installed workflow: bc-prd-spec-gate.yml
OK:   Installed workflow: bc-dependency-update-advisor.yml
OK:   Installed workflow: bc-sprint-closeout-branch-audit.yml
INFO: Skipping unsupported workflow: bc-asset-health.yml
INFO: Skipping unsupported workflow: bc-sync-test.yml
INFO: Skipping unsupported workflow: bc-template-validation.yml

Summary:
  Copied:  6
  Removed: 0
  Skipped: 3
```

### Running Installed Workflows Manually

After installation, you can trigger workflows with the GitHub CLI:

```bash
# List all BaseCoat workflows
gh workflow list | grep bc-

# Run a specific workflow
gh workflow run bc-secret-scan.yml

# Run with custom parameters
gh workflow run bc-sprint-closeout-branch-audit.yml \
  --field stale_days=14 \
  --field apply_changes=true

# View recent runs
gh run list --workflow bc-version-check.yml
```

## Troubleshooting

### Issue: "Source workflow directory not found"

**Problem**: The script cannot find `.github/base-coat/workflows/`.

**Solution**:

- Ensure you've run `pwsh scripts/sync.ps1` first to sync BaseCoat assets
- Verify the BaseCoat sync completed without errors
- Check that `.github/base-coat/workflows/` exists: `ls .github/base-coat/workflows/`

---

### Issue: "This script must be run inside a git repository"

**Problem**: The script was executed outside a git repository.

**Solution**:

- Ensure you're in the root of your consumer repository: `pwd`
- Verify `.git/` exists: `ls -la .git/`
- Run the script again from the repository root

---

### Issue: Workflows not triggering or running

**Problem**: Installed workflows don't appear in the GitHub UI or don't run on expected triggers.

**Solution**:

- Verify workflows are installed: `ls -la .github/workflows/bc-*.yml`
- Check that files are committed and pushed: `git log --oneline -- .github/workflows/`
- Go to the **Actions** tab in your repository to see available workflows
- Workflows may be disabled in repository settings; enable them in **Settings > Actions > General**
- Check the workflow's trigger conditions match your repository events (e.g., push, pull_request)

---

### Issue: Permission errors or 403 responses

**Problem**: The script cannot write to `.github/workflows/`.

**Solution**:

- Ensure you have write permissions to the repository
- Verify `.github/workflows/` directory exists and is writable: `chmod +x .github/workflows/`
- Check your git config: `gh auth status` should show your authenticated account

---

### Issue: Unsupported workflows still present after installation

**Problem**: Phase 2 workflows like `bc-asset-health.yml` remain after installation.

**Solution**:

- The script removes unsupported workflows by default
- To keep them, use: `pwsh scripts/configure-downstream-workflows.ps1 -KeepUnsupported`
- To manually remove: `rm .github/workflows/bc-asset-health.yml`

---

### Issue: Script says "Removed unknown downstream workflow"

**Problem**: The script deleted a `bc-*.yml` file that wasn't in the expected list.

**Explanation**: The script has a safety mechanism to remove `bc-` prefixed workflows that aren't
part of the BaseCoat-distributed set. This prevents stale workflows from lingering.

**Solution**:

- If you created custom workflows with the `bc-` prefix, rename them to avoid the prefix
- To preserve unknown `bc-` files, use: `pwsh scripts/configure-downstream-workflows.ps1 -KeepUnknownBc`

## FAQ

### What if my repository is not a BaseCoat consumer?

If your repository hasn't imported BaseCoat yet, you can:

1. Run `pwsh scripts/sync.ps1` to bring in BaseCoat assets (requires `base-coat/` directory in your repo)
2. Or manually copy workflows from the [BaseCoat repository](https://github.com/IBuySpy-Shared/basecoat)
   to `.github/base-coat/workflows/`
3. Then run the installer script

### Why are some workflows marked unsupported?

Phase 2 workflows (`asset-health.yml`, `sync-test.yml`, `template-validation.yml`) depend on:

- BaseCoat-specific asset structures (agents, skills, instructions)
- Internal tooling or scripts not universally available
- Assumptions about repository organization

These workflows require consumer-specific adaptation and are not recommended for general use.
They may become Phase 1 (downstream-safe) in future releases as we generalize their logic.

### Can I customize the installed workflows?

Yes. After installation, you can:

- Edit the `.yml` files in `.github/workflows/` to adjust triggers, inputs, or steps
- Disable workflows by renaming them (e.g., `bc-secret-scan.yml` → `bc-secret-scan.yml.disabled`)
- Delete workflows you don't use
- Override workflow behavior with repository settings

Changes will persist in your repository and won't be lost on re-runs of the installer script.

### Can I contribute new downstream workflows back to BaseCoat?

Absolutely! If you create a generic, reusable workflow that works in consumer repositories:

1. Open an issue in the [BaseCoat repository](https://github.com/IBuySpy-Shared/basecoat) with:
   - Your workflow file
   - Use case and consumer value
   - Any prerequisites or configuration requirements
   - Testing evidence from your repository

2. We'll review it for:
   - Generalizability across different org structures
   - Security and compliance
   - Alignment with BaseCoat standards

3. If accepted, your workflow will be added to Phase 1 or Phase 2 depending on its dependencies.

### What if I want only specific workflows?

The installer script copies all Phase 1 workflows by default. To customize:

1. **Dry-run first**: `pwsh scripts/configure-downstream-workflows.ps1 -DryRun`
2. **Install all**: `pwsh scripts/configure-downstream-workflows.ps1`
3. **Manually remove unwanted workflows**: `rm .github/workflows/bc-<workflow-name>.yml`
4. **Commit your subset**: `git add .github/workflows/` && `git commit -m "..."`

There is no built-in "install specific workflows only" mode, but you can achieve this by
deleting the workflows you don't need after installation.

### How do I keep workflows updated?

When BaseCoat releases new versions:

1. Update your BaseCoat sync: `pwsh scripts/sync.ps1` (usually automated via workflow)
2. Re-run the installer: `pwsh scripts/configure-downstream-workflows.ps1`
3. Review changes: `git diff .github/workflows/bc-*.yml`
4. Commit: `git add .github/workflows/` && `git commit -m "chore: update BaseCoat downstream workflows"`

The installer is idempotent—running it multiple times is safe and only updates changed workflows.

### Where do I report issues with downstream workflows?

File issues in the [BaseCoat repository](https://github.com/IBuySpy-Shared/basecoat):

- Include the workflow name (e.g., `bc-secret-scan.yml`)
- Describe the expected vs. actual behavior
- Provide error logs or workflow run output
- Include your repository structure (if relevant to the issue)

## Next Steps

- [BaseCoat Workflows Reference](./workflows-reference.md) — Complete spec for all 9 workflows
- [BaseCoat Distribution Guide](../reference/DISTRIBUTION.md) — How BaseCoat assets are synced
- [Contributing to BaseCoat](../CONTRIBUTING.md) — Submit improvements or new workflows

---

**Last Updated**: 2026-06-06

**BaseCoat Version**: 3.30.5+
