# Getting Started with BaseCoat Workflows

BaseCoat distributes workflow templates for consumer repositories. Use the installer script to copy and configure downstream-safe workflows with explicit BaseCoat provenance filenames.

For centralized fleet audits of downstream reviewer-routing health, see `downstream-reviewer-routing-audit.md`.
For weekly post-onboarding drift detection with remediation issue dedupe and trend scorecards, see `.github/workflows/post-onboarding-drift-loop.yml`.

## What's Included

Supported distributable workflows by class:

| Class | Installed by default | Workflows |
|----------|---------|---------|
| **Reusable** | Yes | `basecoat-upstream-version-drift.yml`, `basecoat-version-check.yml`, `basecoat-secret-scan.yml` |
| **Ship-it** | Yes | `ship-it-intent-dispatch.yml`, `ship-it-build-guard.yml`, `ship-it-release-gate.yml` (all three install together per the skill's fail-closed contract; see issue #2943) |
| **Onboarding-telemetry** | No (`-InstallClass onboarding-telemetry`) | `adoption-metrics.yml` (autonomous, scheduled, write-permission workflow -- opt-in) |
| **Templates** | No (`-IncludeTemplates`) | `basecoat-dependency-update-advisor.yml`, `basecoat-issue-approve.yml`, `basecoat-pr-auto-merge-executor.yml`, `basecoat-sprint-closeout-branch-audit.yml`, `basecoat-token-inventory.yml` |
| **Internal** | No (`-IncludeInternal`) | Internal-only automation workflows (unsupported in downstream consumer repos) |

## Installation

### Automatic (Recommended)

Run the downstream workflow installer from your consumer repository:

```bash
pwsh scripts/configure-downstream-workflows.ps1
```

This installs (default reusable + ship-it classes):

- `basecoat-upstream-version-drift.yml`
- `basecoat-version-check.yml`
- `basecoat-secret-scan.yml`
- `ship-it-intent-dispatch.yml`
- `ship-it-build-guard.yml`
- `ship-it-release-gate.yml`

To install only the reusable class (skip ship-it):

```bash
pwsh scripts/configure-downstream-workflows.ps1 -InstallClass reusable
```

To include template workflows:

```bash
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates
```

This also installs the companion governance policy files used by template workflows:

- `.github/governance/policy-packs.json`
- `.github/governance/human-approval-boundaries.json`

For a single-maintainer repository, follow the
[Solo-Developer Governance Profile](solo-dev-profile.md) before enabling
`basecoat-pr-auto-merge-executor.yml`. The profile requires protected `main`,
all policy-pack checks, an empty bypass list, and GitHub-native auto-merge.

To include internal workflows as well (internal workflows are marked unsupported,
so include both flags):

```bash
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates -IncludeInternal -IncludeUnsupported
```

By default it skips advanced unsupported workflows, including:

- `basecoat-agent-code-review.yml`
- `basecoat-agent-issue-triage.yml`
- `basecoat-agent-release-impact-advisor.yml`
- `basecoat-agent-retro-facilitator.yml`
- `basecoat-agent-security-analyst.yml`
- `basecoat-agent-self-healing-ci.yml`
- `basecoat-internal-auto-approve-cloud-agent-workflows.yml`

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

Enforces PRD/spec intake evidence on high-change PRs and warns on risky-path PRs.

**Built-in policy (no workflow inputs):**

- High-change threshold: `changed_files >= 12` and `additions + deletions >= 500`
- Risky paths: `instructions/`, `skills/`, `agents/`, `scripts/`, `.github/workflows/`
- High-change PRs must include both PRD and spec references in PR description
- Risky-path-only PRs get advisory warning when no PRD/spec reference is present
- References can be markdown links or structured lines (`PRD: <link>`, `Spec: <link>`)
- Merge queue events auto-pass (no PR body payload)
- Bot/agent-authored PRs (`ibuyspy` or GitHub Bot accounts) bypass the gate

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
gh workflow run basecoat-upstream-version-drift.yml \
  --ref main \
  --field input_param=value
```

### Disabling Workflows

To disable a workflow:

```bash
# Option 1: Rename file (add .disabled extension)
mv .github/workflows/basecoat-sprint-closeout-branch-audit.yml .github/workflows/basecoat-sprint-closeout-branch-audit.yml.disabled

# Option 2: Remove from repository
rm .github/workflows/basecoat-secret-scan.yml

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
gh workflow view basecoat-upstream-version-drift.yml
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
