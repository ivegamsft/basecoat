# BaseCoat Workflow Reference

Reference for upstream workflow templates in BaseCoat. Consumer installs use `scripts/configure-downstream-workflows.ps1`, which currently installs only the supported subset (`reusable` by default, with supported `templates` via opt-in) from `.github/base-coat/workflows`.

## Related operational workflows

- [Portfolio Audit Workflow](./portfolio-audit-workflow.md) for issue/PR dedupe, dependency traceability, feature grouping, and active project-link verification.
- [Downstream Reviewer-Routing Audit](./downstream-reviewer-routing-audit.md) for cross-repo detection and escalation of missing or ineffective reviewer-routing automation.

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
| #1557 | `.github/workflows/pr-flow-hygiene.yml` | Event-driven PR readiness routing (`ready_for_review` + metadata transitions) plus weekly PR lifecycle audit summary |
| #1823 | `.github/workflows/dependency-relationship-routing.yml` | Parses `Blocked by`/`Depends on`/`Part of`/`Related to` markers on issues and PRs, applies blocker labels, and publishes weekly dependency bottleneck reports |
| #1828 | `.github/workflows/downstream-reviewer-routing-audit.yml` | Weekly cross-repo reviewer-routing scorecard; escalates missing/unconfigured/ineffective routing automation states across opted-in consumer repos |
| #1832 | `.github/workflows/post-onboarding-drift-loop.yml` | Weekly post-onboarding drift loop across opted-in repos. Detects branch/ruleset, intake, reviewer-routing, and metadata hygiene drift; opens/updates deduplicated remediation issues; publishes fleet + per-repo trend scorecards |

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

- Automatic: Pull request lifecycle events
- Blocks merge only for high-change PRs if intake evidence is missing
- Supports skip override via PR label

**What It Does:**

- Calculates high-change thresholds from the PR payload:
  - `changed_files >= 12` and
  - `additions + deletions >= 500`
- Detects risky path changes (`instructions/`, `skills/`, `agents/`, `scripts/`, `.github/workflows/`)
- Requires both PRD and spec references for high-change PRs
- Emits advisory warning (non-blocking) for risky-path-only PRs when no PRD/spec reference is present
- Accepts links in markdown or structured lines (`PRD: <link>`, `Spec: <link>`)
- Auto-passes merge queue checks (`merge_group`) when no pull request payload is available
- Bypasses bot/agent-authored PRs (`ibuyspy` or GitHub Bot accounts)

**Configuration:**

- No `workflow_dispatch` inputs for thresholds
- Behavior is fixed in workflow code to keep intake policy consistent across repos

**Bypass:**

- Add label `skip-prd-spec-check` to PR

**Output:**

- Status check (pass/fail)
- Failure message for high-change PRs missing intake links
- Advisory warning for risky-path-only PRs missing intake links

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

**Purpose:** Safely reap proven merged branches and report orphaned lanes that
did not complete local `lane-closeout`

**Trigger:**

- Cron: Every Sunday at 2am UTC
- Manual: `gh workflow run sprint-closeout-branch-audit.yml`

**What It Does:**

- Finds branches merged to main/master
- Identifies branches older than N days
- Deletes only stale merged branches with no open PR or protected WIP prefix
- Retains unverified local branches instead of force-deleting them
- Writes a terminal-state ledger and idempotently creates or updates the
  `Orphaned lane ledger` issue for retained `HANDED_OFF`/`PARKED` lanes
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
  publish_issue:
    description: "Create or update the orphaned-lane issue"
    default: "true"
```

**Output:**

- List of candidate branches for deletion
- Dry-run report or actual deletion
- `orphaned-lane-ledger` workflow artifact
- Marker-keyed open issue containing owner and next-action follow-up for
  retained lanes; the workflow closes it when the ledger returns to zero
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

**Purpose:** Keep PR readiness event-driven after intake, enforce required metadata quickly, and retain a weekly hygiene report as the audit layer.

**Trigger:**

- Event-driven: `pull_request_target` on `ready_for_review`, `synchronize`, `reopened`, reviewer/assignee transitions, and label changes
- Cron: Every Monday at 1pm UTC (reconciliation + summary / audit)
- Manual: `gh workflow run pr-flow-hygiene.yml`

**What It Does:**

- Routes each PR event through immediate readiness checks:
  - reviewer/team coverage
  - ownership coverage (assignee)
  - release/planning label coverage (`wave:*` or `sprint:*`)
  - `BEHIND` mergeability nudge
- Applies deterministic escalation label (`pr-readiness-blocked`) and upserts routing comments when metadata is incomplete
- Removes `pr-readiness-blocked` automatically once the PR passes readiness checks
- Scans open PRs, reconciles `pr-readiness-blocked` label state, and publishes a weekly `PR Flow Hygiene Report` issue
- Treats the flagged PR set as the remaining WIP follow-up queue for the full lifecycle
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

- Event-cycle PR comments and label updates for readiness routing gaps
- Weekly issue with PR flow guardrail status table and top-risk PR lists
- Weekly issue with a remaining-WIP follow-up count and top-risk PR lists
- PR comments for actionable ownership/reviewer/drift nudges
- Step summary metrics for run-level observability

**Consumer Value:**

- Same-cycle readiness feedback instead of waiting for weekly cadence
- Deterministic escalation signal for blocked readiness states
- Fixed cadence for backlog triage outcomes
- Explicit WIP and handoff policy signal
- Reduced draft and review drift through targeted automation

---

### 11. dependency-relationship-routing.yml

**Purpose:** Operationalize relationship markers into issue/PR blocker state, approval routing safety, and dependency-chain visibility.

**Trigger:**

- Event-driven: `issues`, `issue_comment`, `pull_request_target`, `pull_request_review_comment`
- Cron: Every Monday at 9am UTC (dependency routing audit report)
- Manual: `gh workflow run dependency-relationship-routing.yml`

**What It Does:**

- Parses relationship markers in issue/PR body and comments:
  - `Blocked by #N`
  - `Depends on #N`
  - `Part of #N`
  - `Related to #N`
- Treats `Blocked by` and `Depends on` as blocker edges and resolves targets by state:
  - Issues must be `closed`
  - Pull requests must be `merged`
- Applies/removes deterministic blocker labels:
  - Issues: `blocked`
  - Pull requests: `dependency-blocked`
- Upserts an in-thread routing status comment with parsed markers and unresolved blockers.
- Publishes a weekly `Dependency Routing Report` issue summarizing blocked counts, hottest blockers, and stale blocked items.

**Configuration:**

```yaml
inputs:
  max_items:
    description: "Maximum open issues and PRs to evaluate in batch mode"
    default: "150"
  stale_days:
    description: "Days since update to classify blocked work as stale"
    default: "7"
```

**Output:**

- Event-cycle blocker labels and routing comments
- Weekly dependency report issue with bottleneck and stale-blocked visibility
- Step summary metrics for run-level observability

**Consumer Value:**

- Dependency blockers become machine-actionable state
- Blocked issues/PRs are discoverable without manual comment inspection
- Weekly bottleneck visibility for dependency-chain triage

---

### 12. post-onboarding-drift-loop.yml

**Purpose:** Keep onboarded repositories aligned with their governance/profile contract after onboarding by running a weekly drift loop with deduplicated remediation issue automation.

**Trigger:**

- Cron: Every Monday at 10am UTC
- Event-driven: `workflow_run` after successful `BaseCoat - Adoption Metrics`
- Manual: `gh workflow run post-onboarding-drift-loop.yml`

**What It Does:**

- Uses `.github/downstream-reviewer-routing-targets.json` as the default opted-in repo registry
- Detects drift in four contract surfaces:
  - branch/ruleset protection posture
  - intake surface presence (issue + PR templates)
  - reviewer-routing automation effectiveness in live ready PRs
  - metadata hygiene surfaces
- Opens/updates one remediation issue per repo when drift is present
- Closes remediation issues when the repo returns to healthy state
- Publishes an aggregate + per-repo scorecard issue with trend classification (`regression`, `improvement`, `stable`, `new`)

**Configuration:**

```yaml
inputs:
  repositories:
    description: "Optional comma-separated owner/repo list"
    default: ""
  reviewer_gap_threshold:
    description: "Escalation threshold for ready PRs with no reviewer requests"
    default: 3
```

**Output:**

- Fleet scorecard issue: `Post-onboarding drift fleet scorecard`
- Deduplicated remediation issues labeled `drift-remediation`
- Artifacts: `post-onboarding-drift-scorecard.md`, `post-onboarding-drift-latest.json`

**Consumer Value:**

- Prevents profile/governance decay after initial onboarding
- Creates persistent remediation ownership without duplicate issue noise
- Distinguishes regressions from improvements week-over-week

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
    with:
      # Required: the BaseCoat source repository whose releases define the
      # latest version. Replace with your BaseCoat upstream in owner/repo form.
      source_repo: YOUR-ORG/basecoat
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
