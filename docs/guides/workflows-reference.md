# BaseCoat Workflow Reference

Reference for upstream workflow templates in BaseCoat. Consumer installs use `scripts/configure-downstream-workflows.ps1`, which currently installs only the supported subset (`reusable` by default, with supported `templates` via opt-in) from `.github/base-coat/workflows`.

## Consolidated Workflow Enhancements (#1389)

The following workflows implement the consolidated production enhancement set for
issues #181 through #190. Each workflow includes `workflow_dispatch` for manual
testing and uses pinned action SHAs.

| Issue | Workflow | Purpose |
|---|---|---|
| #181 | `.github/workflows/dependency-audit.yml` | Weekly dependency audit across lockfiles with issue tracking output |
| #182 | `.github/workflows/stale-management.yml` | Auto-mark and auto-close stale issues/PRs with configurable thresholds |
| #183 | `.github/workflows/release-changelog-generation.yml` | Generate changelog content from release events and open update PRs |
| #184 | `.github/workflows/cross-repo-sync-validation.yml` | Validate consumer repos are within a configurable version drift window |
| #185 | `.github/workflows/docs-link-checker.yml` | Nightly external docs link checks with report artifacts and issue updates |
| #186 | `.github/workflows/skill-coverage-report.yml` | Scheduled report of skills missing `eval.yaml` coverage |
| #187 | `.github/workflows/repo-health-check.yml` | Scheduled lint/validate/test health run with badge-ready status |
| #188 | `.github/workflows/pr-size-labeler.yml` | Automatic PR size labels (`size:XS`..`size:XL`) from diff size |
| #189 | `.github/workflows/dependency-graph-pages.yml` | Generate dependency graph report and publish via docs PR flow |
| #190 | `.github/workflows/reviewer-autoassign.yml` | Auto-request reviewers using changed-path commit history |
| #1557 | `.github/workflows/pr-flow-hygiene.yml` | Weekly PR flow report with WIP limits, draft-drift triage, and owner/reviewer nudges |

## Distributed Workflow Templates (10 Total)

### 1. asset-health.yml

**Purpose:** Automated asset quality scoring (agents, skills, instructions)

**Trigger:**

- Cron: Every Monday at 8am UTC
- Manual: `gh workflow run asset-health.yml`

**What It Does:**

- Scores each asset on multiple dimensions
- Opens GitHub issue if any asset grades "F"
- Reports results in pull requests
- Grades: A (excellent), B (good), C (fair), D (poor), F (fail)

#### No Configuration Required

**Output:**

- GitHub Step Summary with scoring table
- GitHub Issue (if any asset fails)
- PR comment with results (on PRs with asset changes)

**Consumer Value:**

- Enforce asset quality standards
- Catch incomplete documentation early
- Standardize asset structure across org

---

### 2. check-version.yml

**Purpose:** Version consistency checks across repository

**Trigger:**

- Manual: `gh workflow run check-version.yml`
- Callable from other workflows

**What It Does:**

- Validates version.json alignment
- Checks version consistency across files
- Verifies version format compliance
- Callable workflow for reuse

#### No Configuration Required

**Output:**

- Pass/fail status
- Detailed version report
- Can be used as gate in other workflows

**Consumer Value:**

- Prevent version mismatches in releases
- Standardize version management
- Automated release prep checks

---

### 3. dependency-update-advisor.yml

**Purpose:** Dependency security advisory

**Trigger:**

- Cron: Weekly (customizable)
- Manual: `gh workflow run dependency-update-advisor.yml`

**What It Does:**

- Runs npm audit
- Checks for known vulnerabilities
- Reports severity levels
- Recommends updates

**Configuration:**

```yaml
inputs:
  package_manager:
    description: "Package manager (npm, pip, cargo, etc.)"
    default: "npm"
```

**Output:**

- Vulnerability report with severity
- Recommended updates
- CVSS scores where available

**Consumer Value:**

- Stay informed of security issues
- Automate dependency monitoring
- Reduce manual security audits

---

### 4. prd-spec-gate.yml

**Purpose:** Enforce documentation for large changes

**Trigger:**

- Automatic: On pull requests that exceed size thresholds
- Blocks merge if PRD/spec missing (can override with label)

**What It Does:**

- Checks PR size (lines changed)
- Checks file count
- Requires PRD/spec links for large PRs
- Advisory-only for smaller changes

**Configuration:**

```yaml
inputs:
  size_threshold:
    description: "PR size threshold (default: 500 lines)"
    default: "500"
  file_count_threshold:
    description: "File count threshold (default: 12 files)"
    default: "12"
```

**Bypass:**

- Add label `skip-prd-spec-check` to PR

**Output:**

- Status check (pass/fail)
- Comment with PRD/spec link requirements
- Advisory warning for medium changes

**Consumer Value:**

- Enforce architecture review process
- Catch breaking changes early
- Standardize documentation practice

---

### 5. secret-scan.yml

**Purpose:** Prevent accidental secret/credential commits

**Trigger:**

- Push to any branch
- Pull request changes

**What It Does:**

- Scans for hardcoded secrets (API keys, tokens, passwords)
- Detects common credential patterns
- Prevents push if secrets found
- False-positive handling

#### No Configuration Required

**Output:**

- Blocks commits with detected secrets
- Shows secret location + type
- Recommends using GitHub Secrets

**Consumer Value:**

- Prevent credential exposure
- Enforce secret management best practices
- Automated security baseline

---

### 6. sprint-closeout-branch-audit.yml

**Purpose:** Clean up merged/stale branches

**Trigger:**

- Cron: Every Sunday at 2am UTC
- Manual: `gh workflow run sprint-closeout-branch-audit.yml`

**What It Does:**

- Finds branches merged to main/master
- Identifies branches older than N days
- Optionally deletes stale branches
- Dry-run mode for safety

**Configuration:**

```yaml
inputs:
  stale_days:
    description: "Branch age threshold in days"
    default: "30"
  apply_changes:
    description: "Actually delete branches (true/false)"
    default: "false"
```

**Output:**

- List of candidate branches for deletion
- Dry-run report or actual deletion
- Summary of cleanup actions

**Consumer Value:**

- Reduce branch clutter
- Automatic sprint cleanup
- Easier branch navigation

---

### 7. sync-test.yml

**Purpose:** Validate sync.ps1/sync.sh correctness

**Trigger:**

- Manual: `gh workflow run sync-test.yml`
- Part of sync validation pipeline

**What It Does:**

- Tests sync script syntax
- Validates sync logic
- Checks distribution package contents
- Verifies consumer sync compatibility

#### No Configuration Required

**Output:**

- Sync validation report
- Error details if validation fails
- Ready/not-ready status

**Consumer Value:**

- Verify distribution integrity
- Validate sync processes
- Catch sync errors early

---

### 8. template-validation.yml

**Purpose:** Validate template file structure

**Trigger:**

- Manual: `gh workflow run template-validation.yml`
- Pull request (optional)

**What It Does:**

- Checks template YAML syntax
- Validates template structure
- Verifies required fields
- Checks template compatibility

#### No Configuration Required

**Output:**

- Pass/fail for each template
- Detailed error messages
- Structure compliance report

**Consumer Value:**

- Enforce template standards
- Catch template errors early
- Standardize template structure

---

### 9. version-check.yml

**Purpose:** Ensure version consistency

**Trigger:**

- Manual: `gh workflow run version-check.yml`

**What It Does:**

- Validates version.json format
- Checks version alignment across files
- Verifies semantic versioning compliance
- Reports discrepancies

#### No Configuration Required

**Output:**

- Version alignment report
- Pass/fail status
- Detailed version breakdown

**Consumer Value:**

- Prevent version mismatches
- Automated version validation
- Standardize version management

---

### 10. pr-flow-hygiene.yml

**Purpose:** Keep open PR backlog healthy and reduce draft drift.

**Trigger:**

- Cron: Every Monday at 1pm UTC
- Manual: `gh workflow run pr-flow-hygiene.yml`

**What It Does:**

- Scans open PRs and publishes a weekly `PR Flow Hygiene Report` issue
- Evaluates guardrails with configurable thresholds:
  - WIP limit for ready-for-review PRs (default: 20)
  - Draft drift age (default: 14 days)
  - Ready PR inactivity age (default: 7 days)
- Upserts triage nudge comments on highest-risk PRs (owner/reviewer/drift gaps)

**Configuration:**

```yaml
inputs:
  wip_limit:
    description: "Max ready-for-review PRs before WIP warning"
    default: "20"
  draft_drift_days:
    description: "Draft PR age threshold in days"
    default: "14"
  ready_stale_days:
    description: "Ready-for-review inactivity threshold in days"
    default: "7"
  max_items:
    description: "Maximum open PRs to evaluate"
    default: "200"
```

**Output:**

- Weekly issue with PR flow guardrail status table and top-risk PR lists
- PR comments for actionable ownership/reviewer/drift nudges
- Step summary metrics for run-level observability

**Consumer Value:**

- Fixed cadence for backlog triage outcomes
- Explicit WIP and handoff policy signal
- Reduced draft and review drift through targeted automation

---

## Installation & Usage

### Automatic Distribution

Install downstream-safe workflows with:

```bash
pwsh scripts/configure-downstream-workflows.ps1
```

Installed files:

```text
.github/workflows/
├── basecoat-upstream-version-drift.yml
├── basecoat-version-check.yml
└── basecoat-secret-scan.yml
```

### Manual Setup

```bash
# Preview changes
pwsh scripts/configure-downstream-workflows.ps1 -DryRun

# Include unsupported workflows only if your repo provides required scripts
pwsh scripts/configure-downstream-workflows.ps1 -IncludeTemplates -IncludeUnsupported
```

## Common Patterns

### Running Workflows Manually

```bash
# List all workflows
gh workflow list

# Run workflow with defaults
gh workflow run basecoat-version-check.yml

# Run with custom parameters
# (requires template workflows to be installed with -IncludeTemplates)
gh workflow run basecoat-sprint-closeout-branch-audit.yml \
  --field stale_days=14 \
  --field apply_changes=true

# View workflow run
gh run list --workflow basecoat-version-check.yml
```

### Integrating with CI/CD

```yaml
# .github/workflows/your-workflow.yml
jobs:
  my-job:
    uses: ./.github/base-coat/workflows/check-version.yml
    secrets: inherit
```

### Disabling Workflows

```bash
# Rename to disable
mv .github/workflows/basecoat-version-check.yml .github/workflows/basecoat-version-check.yml.disabled

# Delete to remove
rm .github/workflows/basecoat-version-check.yml
```

## Release Notes

**Version 3.10.0** (2026-05-31)

- Initial distribution of 9 generic workflows
- Zero configuration required
- All workflows are production-tested in BaseCoat
- Ready for immediate consumer deployment

---

**Last Updated:** 2026-05-31
