# BaseCoat Workflow Reference

Complete specification of all 9 distributable workflows.

## Distributed Workflows (9 Total)

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

## Installation & Usage

### Automatic Distribution

All 9 workflows are automatically distributed to consumer repositories via BaseCoat sync scripts.

Workflows appear in:

```text
.github/base-coat/workflows/
├── asset-health.yml
├── check-version.yml
├── dependency-update-advisor.yml
├── prd-spec-gate.yml
├── secret-scan.yml
├── sprint-closeout-branch-audit.yml
├── sync-test.yml
├── template-validation.yml
└── version-check.yml
```

### Manual Setup

```bash
# Copy to your repository
cp -r .github/base-coat/workflows/* .github/workflows/

# Or copy individual workflows
cp .github/base-coat/workflows/asset-health.yml .github/workflows/
```

## Common Patterns

### Running Workflows Manually

```bash
# List all workflows
gh workflow list

# Run workflow with defaults
gh workflow run asset-health.yml

# Run with custom parameters
gh workflow run sprint-closeout-branch-audit.yml \
  --field stale_days=14 \
  --field apply_changes=true

# View workflow run
gh run list --workflow asset-health.yml
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
mv .github/workflows/asset-health.yml .github/workflows/asset-health.yml.disabled

# Delete to remove
rm .github/workflows/asset-health.yml
```

## Release Notes

**Version 3.10.0** (2026-05-31)

- Initial distribution of 9 generic workflows
- Zero configuration required
- All workflows are production-tested in BaseCoat
- Ready for immediate consumer deployment

---

**Last Updated:** 2026-05-31
