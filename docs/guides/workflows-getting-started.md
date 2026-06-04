# Getting Started with BaseCoat Workflows

BaseCoat distributes workflow templates for consumer repositories. Use the installer script to copy and configure only downstream-safe workflows with `bc-` prefixed filenames.

## What's Included

Nine generic workflows with **zero BaseCoat dependencies**:

| Workflow | Purpose | Trigger | Setup Time |
|----------|---------|---------|-----------|
| **asset-health.yml** | Asset quality scoring | Cron (Mon 8am) | 1 min |
| **check-version.yml** | Version consistency checks | Manual | 1 min |
| **dependency-update-advisor.yml** | Dependency advisory | Cron + Manual | 1 min |
| **prd-spec-gate.yml** | Enforce PRD/spec documentation | PR labels | 2 min |
| **secret-scan.yml** | Secret/credential scanning | Push, PR | 1 min |
| **sprint-closeout-branch-audit.yml** | Cleanup stale branches | Cron (Sun 2am) | 2 min |
| **sync-test.yml** | Validate sync correctness | Manual | 1 min |
| **template-validation.yml** | Validate template structure | Manual, PR | 1 min |
| **version-check.yml** | Version alignment | Manual | 1 min |

## Installation

### Automatic (Recommended)

Run the downstream workflow installer from your consumer repository:

```bash
pwsh scripts/configure-downstream-workflows.ps1
```

This installs:

- `bc-check-health.yml`
- `bc-version-check.yml`
- `bc-secret-scan.yml`
- `bc-prd-spec-gate.yml`
- `bc-dependency-update-advisor.yml`
- `bc-sprint-closeout-branch-audit.yml`

By default it skips/removes unsupported consumer workflows:

- `bc-asset-health.yml`
- `bc-sync-test.yml`
- `bc-template-validation.yml`

### Manual Setup

Use dry-run mode to preview changes before applying:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -DryRun
```

## Quick Start Guide

### 1. Asset Health (Asset Quality Scoring)

Automatically scores agents, skills, and instructions every Monday at 8am UTC.

**No configuration needed** — just enable the workflow.

```yaml
# Enables automatically on schedule
# Opens issue if any asset grades "F"
# Reports on pull requests
```

**What it grades:**

- Completeness (README, examples, etc.)
- Consistency (naming, structure)
- Quality (tests, documentation)

### 2. Secret Scan (Security Baseline)

Scans all pushes and pull requests for leaked secrets/credentials.

**No configuration needed** — just enable.

```yaml
# Runs on every push + PR
# Blocks commits with detected secrets
# Prevents accidental credential exposure
```

### 3. Dependency Update Advisor

Weekly dependency advisory for your repository.

**No configuration needed** — just enable.

```yaml
# Cron: Weekly (configurable)
# Manual: workflow_dispatch
# Runs npm audit, safety, etc.
```

### 4. Version Check

Ensures version.json stays in sync with your codebase.

```bash
# Run manually with:
gh workflow run version-check.yml
```

### 5. PR Spec Gate

Enforces PRD/spec documentation for large changes.

**Customize via workflow inputs:**

```yaml
inputs:
  size_threshold:
    description: "PR size threshold (default: 500 lines)"
    default: "500"
  file_count_threshold:
    description: "File count threshold (default: 12 files)"
    default: "12"
```

**Skip check:** Add `skip-prd-spec-check` label to PR

### 6. Branch Cleanup (Sprint Hygiene)

Automatically cleans up merged/stale branches older than 30 days.

**Customize via workflow inputs:**

```yaml
inputs:
  stale_days:
    description: "Branch age threshold in days"
    default: "30"
```

### 7. Template Validation

Validates template file structure compliance.

```bash
# Run manually with:
gh workflow run template-validation.yml
```

## Customization

### Per-Workflow Configuration

Each workflow accepts `workflow_dispatch` inputs for customization:

```bash
# Run with custom parameters
gh workflow run bc-check-health.yml \
  --ref main \
  --field input_param=value
```

### Disabling Workflows

To disable a workflow:

```bash
# Option 1: Rename file (add .disabled extension)
mv .github/workflows/bc-sprint-closeout-branch-audit.yml .github/workflows/bc-sprint-closeout-branch-audit.yml.disabled

# Option 2: Remove from repository
rm .github/workflows/bc-secret-scan.yml

# Option 3: Set status=skipped in workflow file
# status: skipped
```

## Troubleshooting

### Workflow Not Running

**Check:**

1. Workflow file exists in `.github/workflows/`
2. File has `.yml` or `.yaml` extension
3. No syntax errors (validate with `gh workflow list`)
4. Schedule/trigger conditions are met

```bash
# List all workflows
gh workflow list --all

# View workflow details
gh workflow view bc-check-health.yml
```

### Permission Errors

Some workflows require specific permissions. Grant them in your repository:

1. Go to **Settings** → **Actions** → **General**
2. Set **Workflow permissions** to:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

### Secret/Token Errors

Most workflows don't require secrets. If you see token errors:

1. Check repo has `GITHUB_TOKEN` (default)
2. Verify workflow permissions (above)
3. Check branch protection rules aren't blocking

## For More Information

- **Workflow Reference:** See `workflows-reference.md` for detailed specs
- **Customization:** Each workflow file contains inline documentation
- **Examples:** See `docs/examples/workflow-setups/`
- **Contributing:** File issues or suggestions on GitHub

## Support

Questions? File an issue:

- **Bug report:** Include workflow name + error message
- **Feature request:** Describe use case + desired behavior
- **Question:** Check existing issues first

---

**Last Updated:** 2026-05-31  
**Version:** 3.10.0 (Initial Release)
