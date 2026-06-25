<!-- markdownlint-disable MD009 MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->

# Contributing to BaseCoat

basecoat is a GitHub Enterprise template for agentic development shops. It must follow its own advice.
This document is the canonical reference for how changes are made — by humans and AI agents alike.

---

## Issue-First Workflow

**Every meaningful change starts with an issue.**

| Change Type | Issue Required? |
|---|---|
| New file, agent, skill, or instruction | ✅ Yes |
| Bug fix or typo affecting behavior | ✅ Yes |
| Typo-only or whitespace fix | ❌ Inline is fine |
| Dependency bump with no logic change | ❌ Inline is fine |
| Documentation rewrite | ✅ Yes |

If you are an AI agent: **do not begin implementation without an issue number**. If no issue exists, create one first, then proceed.

---

## Branch Naming

```text
<type>/<issue-number>-<short-description>
```

| Type | When to Use |
|---|---|
| `feat` | New feature or content |
| `fix` | Bug or correctness fix |
| `docs` | Documentation only |
| `chore` | Maintenance, deps, CI |
| `security` | Security-related changes |

**Examples:**

```text
feat/43-governance-docs
fix/17-hook-glob-pattern
docs/39-readme-overhaul
```

No direct commits to `main`. Ever.

---

## Pull Request Process

1. **Create a branch** from `main` using the naming convention above.
2. **Make your changes** — keep scope tight to the issue.
3. **Open a PR** referencing the issue: `closes #<issue-number>` in the description.
4. **Self-review** your diff before requesting review.
5. **All CI checks must pass** before merge.
6. **At least one approval** required (human or designated AI reviewer).
7. **Squash-merge** preferred to keep `main` history clean.

### Batch PR Size Guideline

- Prefer one issue per PR.
- Batch only tightly related changes that can be reviewed together.
- Keep batch PRs to **12 files or fewer** and **400 changed lines or fewer** (additions + deletions) to stay below the PRD/spec gate threshold.
  - The gate policy (see table below) requires both PRD and spec references for high-change PRs (`>=12 files` or `>=500 churn`). For details, see [PRD And Spec Guidance](./docs/guides/prd-and-spec-guidance.md).
- If you must exceed these limits, split the work or explain the mechanical reason in the PR description and include the required PRD and spec references.
- Large mechanical batches should include a validation summary and rollback note.

**PR Title Format:**

```text
<type>: <short description> (closes #<issue-number>)
```

**Examples:**

```text
feat: governance framework documentation (closes #43)
fix: commit-msg hook glob pattern (closes #17)
```

---

## Commit Message Format

```text
<type>(<scope>): <short summary>

- Optional bullet points for detail
- Reference issue: #<number>

Co-authored-by: <name> <email>  # if applicable
```

**Types:** `feat`, `fix`, `docs`, `chore`, `security`, `test`, `refactor`

**Rules:**

- First line ≤ 72 characters
- Reference the issue number
- No secrets, tokens, keys, passwords, or PII — ever
- Keep messages descriptive but non-sensitive
- Do not embed payloads, credentials, or connection strings

---

## Secret Policy

**Never commit secrets.** This is non-negotiable.

What counts as a secret:

- API keys, tokens, client secrets
- Passwords, passphrases, PINs
- Connection strings with credentials embedded
- Private keys or certificates
- PII (names, emails, IDs) not required for the change

**If you accidentally commit a secret:**

1. Rewrite history immediately (`git rebase`, `git filter-branch`, or BFG)
2. Rotate the affected credential immediately
3. Notify the repo owner

The `.githooks/commit-msg` hook scans commit messages for secret patterns. Install it:

```bash
bash scripts/install-git-hooks.sh
# or on Windows:
pwsh scripts/install-git-hooks.ps1
```

---

## Review Expectations

**For authors:**

- Keep PRs focused — one issue per PR
- Write a clear summary and validation steps in the PR description
- Call out any deviations from standards and why

**For reviewers:**

- Check that the change matches the linked issue
- Verify no secrets or PII are present
- Confirm tests or validation steps are included where applicable
- Approve explicitly — do not merge without review

**AI agents acting as reviewers** must apply the same standards. An AI approval carries the same weight as a human approval and the same accountability.

---

## Issue Labeling Standards

All issues MUST include at least one label for discoverability and sprint tracking.

### Required Labels

Every issue should include:

- **One asset type label** (if applicable): `agent`, `skill`, `instruction`, `prompt`
- **One issue type label**: `bug`, `enhancement`, `documentation`, `question`, `chore`, `security`
- **One sprint label** (if assigned to a sprint): `sprint-1`, `sprint-2`, `sprint-3`, `sprint-4`

### Recommended Labels

- **Priority**: `priority:high` (1hr SLA), `priority:medium` (4hr SLA), `priority:low` (1 week SLA)
- **Technology/Domain**: `azure`, `dotnet`, `kubernetes`, `python`, `terraform`, etc.
- **Blocking**: `blocked` (if waiting on a dependency), `spec-required` (if needs PRD before work starts)

### Labeling Workflow

1. **When creating an issue:** Apply at least one label from each required category
2. **When starting work:** Add sprint label (e.g., `sprint-3`) and priority if not already set
3. **When blocked:** Add `blocked` label and explain in a comment
4. **When closing:** Labels carry forward to related issues for tracking

### Label Taxonomy Reference

Complete reference: [`docs/LABEL_taxonomy.md`](../docs/LABEL_taxonomy.md)

GitHub search examples:

- `is:issue label:agent` — Find all agent-related issues
- `is:issue label:sprint-3 label:enhancement` — Find Sprint 3 enhancements
- `is:issue label:priority:high is:open` — Find open high-priority issues

---

## Adding Agents, Skills, and Instructions

- **Agents** go in `agents/`. Use existing agents as templates.
- **Skills** go in `skills/<skill-name>/`. Every skill needs a `SKILL.md`.
- **Instructions** go in `instructions/`. Every instruction needs frontmatter with `description` and `applyTo`.
- **Templates** go in `docs/templates/`.

All new agents, skills, and instructions require an issue before implementation.

### Internal Operational Workflows

These workflows are **not intended for distribution or consumer use**:

- `memory-audit.yml`: Quarterly audit of memory file freshness and validity
- `memory-contribute.yml`: Dispatch workflow for storing learned facts in memory repo
- `adoption-metrics.yml`: Collect and publish adoption metrics dashboard
- `fork-import.yml`: Import issues from development forks
- `memory-sweep.yml`: Enterprise memory sweep for learning signals (Phase 2 candidate)

**Rationale**: These workflows are tightly coupled to BaseCoat's internal infrastructure (basecoat-memory repository, metrics collection infrastructure, fork maintenance workflow). Consumer value is lower than agentic workflows, and dependency on BaseCoat-specific infrastructure makes them less portable.

See `docs/design/memory-workflow-distribution.md` for detailed design rationale and Phase-based distribution strategy.

### Agent Frontmatter Schema

Every agent file (`agents/<name>.agent.md`) must begin with YAML frontmatter containing at minimum the required fields below.

| Field | Required | Description |
|---|---|---|
| `name` | ✅ Yes | Identifier for the agent (typically matches filename without extension) |
| `description` | ✅ Yes | One-line summary of what the agent does and when to use it |
| `tools` | ❌ Optional | List of tools the agent may invoke |
| `model` | ❌ Optional | Model override (e.g., `gpt-4o`, `claude-sonnet-4`) |
| `handoffs` | ❌ Optional | List of VS Code handoff transitions to other agents (see below) |

**Example:**

```yaml
---
name: backend-dev
description: "Backend development agent for APIs, services, and business logic."
tools: [read_file, write_file, list_dir, run_terminal_command]
handoffs:
  - label: Run Code Review
    agent: code-review
    prompt: Review the implementation above for correctness, security, and test coverage.
    send: false
---
```

The `name` and `description` fields are validated by `scripts/validate-basecoat.ps1` and CI.

#### Handoffs

The `handoffs` field enables VS Code to render transition buttons after an agent response,
letting users move to the next agent in a workflow with a pre-filled prompt. Each entry in
the array has four fields:

| Field | Required | Description |
|---|---|---|
| `label` | ✅ Yes | Text shown on the transition button in VS Code |
| `agent` | ✅ Yes | `name` of the target agent (matches filename without `.agent.md`) |
| `prompt` | ✅ Yes | Pre-filled context passed to the target agent |
| `send` | ❌ Optional | `false` (default) lets the user review before sending; `true` auto-sends |

Use `send: false` for all handoffs so users can review and adjust the pre-filled context.
See `docs/agent-handoffs.md` for the full list of implemented handoff chains and guidelines
for authoring effective prompts.

---

## Merge Policy & Build Verification

**This section is mandatory for all contributors — human and AI alike.**

### Branch Protection Rules

The `main` branch enforces the following protections:

- **No direct commits** — all changes must arrive via a pull request
- **Required status checks must pass** before any merge is allowed
- **Stale review dismissal** — approvals are invalidated if new commits are pushed after approval
- **At least one approval** required before merge

### Required Status Checks

Every PR targeting `main` must pass **all** of the following checks before it can be merged:

| Check Name | Workflow | Purpose |
|---|---|---|
| `Markdown lint` | `pr-validation.yml` | Lints changed `.md` files against markdownlint rules |
| `Validate agent file structure` | `pr-validation.yml` | Verifies agents have required frontmatter and sections |
| `Sync script dry-run` | `pr-validation.yml` | Validates sync.sh runs cleanly against a temp consumer repo |
| `version-consistency` | `version-check.yml` | Ensures version.json and latest CHANGELOG.md entry match |
| `prd-spec-gate` | `prd-spec-gate.yml` | Intake contract gate: high-change PRs (`>=12` files or `>=500` churn) **require** both PRD+Spec refs (blocking); risky-path-only PRs get advisory warning (non-blocking) |
| `validate-commit-messages` | `validate-basecoat.yml` | Scans commit messages for secrets and PII patterns |
| `validate-unix` | `validate-basecoat.yml` | Runs full validation suite on Ubuntu |
| `validate-windows` | `validate-basecoat.yml` | Runs full validation suite on Windows |

> **Note:** `Gitleaks` scans run as warn-only and do **not** block merge by design.
> Findings must be reviewed and remediated, but they will not prevent a passing build
> from being merged.

### Agent Guardrail — Mandatory Build Verification Step

**Any AI agent that opens or works a PR must perform this verification before declaring the work done:**

```bash
# Verify all required checks are green before closing a PR
gh pr checks <PR-NUMBER> --repo <owner>/<repo>

# Expected: every listed check shows a ✓ pass status.
# Do NOT merge or mark work complete if any check is pending or failing.
```

Agents must:

1. Open the PR
2. Wait for the check suite to run (poll with `gh pr checks` until all are complete)
3. Confirm every required check shows **pass** status
4. Only then mark the PR as ready to merge / work as done

**Do not declare a PR "done" because it was opened. The PR is done when checks pass and it is merged.**

### No Auto-Merge

Auto-merge is not enabled. Merges require:

1. All required status checks green
2. At least one approval
3. No unresolved conversations

This is intentional — catching a broken build post-merge is significantly more expensive than the few minutes it takes to confirm checks passed first.

### Branch-Protection-Safe Automation Pattern

Automation that modifies repository content must follow the same branch protection model as humans:

1. Create or reset an automation branch (for example `automation/<name>`)
2. Commit generated changes to that branch
3. Push the automation branch
4. Open or update a pull request targeting `main`
5. Let required checks pass, then merge the PR

Do not script `git push ... main` in routine automation workflows. If a special mirror/release workflow requires direct main updates, it must be explicitly documented, narrowly scoped, and reviewed by repo owners.

---

## Cloud Agent Workflow Auto-Approval

When the cloud agent (`app/copilot-swe-agent`) opens a PR, it triggers the GitHub Actions workflows defined in this repository. To streamline execution and reduce manual intervention, the `auto-approve-cloud-agent-workflows.yml` workflow automatically approves pending workflows.

### How It Works

1. The cloud agent creates a PR with implementation changes
2. GitHub Actions detects pending workflow runs that require approval
3. The `auto-approve-cloud-agent-workflows.yml` workflow automatically approves them
4. All CI checks proceed without manual maintainer intervention

### Security & Permissions

- **Trigger:** Only activates when `github.actor == 'app/copilot-swe-agent'`
- **Permissions:** Uses `pull-requests: read` and `contents: read` only
- **Approval scope:** Limited to workflow runs associated with the agent's PR
- **Error handling:** Fails gracefully if insufficient permissions; logs warnings instead of blocking

### Skipping Auto-Approval

If you need to prevent auto-approval for a specific PR (e.g., for sensitive changes), you can:

1. Manually cancel the pending workflows via GitHub UI
2. Add a label to the PR (custom label-based skipping not yet implemented — file an issue if needed)
3. Disable the workflow temporarily by removing or renaming `.github/workflows/auto-approve-cloud-agent-workflows.yml`

### Troubleshooting

**Issue:** Workflows still require manual approval

- **Cause:** The workflow may not have permissions to approve, or the API call failed silently
- **Fix:** Check the `auto-approve-cloud-agent-workflows` workflow run logs for error messages

**Issue:** Unrelated workflows are being approved

- **Cause:** The filter is too broad or includes unintended workflow types
- **Fix:** Update the workflow filtering logic in `.github/workflows/auto-approve-cloud-agent-workflows.yml` and file an issue

---

## Adoption Tooling

Base Coat provides tools to track, measure, and monitor asset adoption across your GitHub organization.

### 1. Adoption Scanner (`scripts/adoption/detect-basecoat.ps1`)

Scans all repositories in your organization to detect which ones have synced Base Coat assets, including version alignment and custom modifications.

**Usage:**

```powershell
# Scan default org (IBuySpy-Shared) and output as table
./scripts/adoption/detect-basecoat.ps1

# Scan specific org and output as JSON
./scripts/adoption/detect-basecoat.ps1 -Org "MyOrg" -OutputFormat json

# Output as markdown (good for reports)
./scripts/adoption/detect-basecoat.ps1 -OutputFormat markdown
```

**What it reports:**

- Which repos have synced assets (agents, instructions, prompts, skills)
- How many assets are **current** vs. **stale** (version drift)
- Custom assets (local modifications not from Base Coat)
- Overall **coverage %** — how many Base Coat assets are present
- Active Copilot seats in the organization

**Output formats:**

- `table` (default) — Human-readable terminal output
- `json` — Machine-readable for integration with dashboards
- `markdown` — Formatted for GitHub issues, reports, or email

### 2. Metrics Collector (`scripts/metrics/collect-metrics.py`)

Continuously collects and tracks metrics for Base Coat adoption alongside development metrics (PR velocity, CI success, issue resolution).

**Usage:**

```bash
export GITHUB_TOKEN="<your-token>"
export DASHBOARD_ORG="IBuySpy-Shared"
export DASHBOARD_REPOS='["org/repo1", "org/repo2"]'
python scripts/metrics/collect-metrics.py
```

**Collected metrics:**

- Base Coat coverage per repository (% of assets synced)
- Copilot usage trends (active users, acceptance rate)
- PR cycle time (median and p95)
- CI/CD success rate
- Issue resolution times
- Degradation alerts (acceptance rate drops, CI failures, cycle time increases)

**Output:**

- `metrics/latest.json` — Current metrics snapshot
- `metrics/history.json` — Time-series data (up to 52 weeks)
- `metrics/alerts.json` — Active degradation signals
- `metrics/SUMMARY.md` — Human-readable summary

**Integration:** Use with GitHub Actions to run daily and feed a dashboard or reporting system.

### 3. Tracking Inventory

The `inventory.md` and `CATALOG.md` files document all available assets (agents, skills, instructions, prompts) with descriptions, keywords, and use cases. Keep these updated when adding or removing assets.

**When to update:**

- Add new agent, skill, or instruction file → add entry to `inventory.md` and `CATALOG.md`
- Remove deprecated asset → remove from both files
- Change description or functionality → update both files

**Format:**

Both files follow Markdown table format with columns for name, file path, description, and keywords. See existing entries for the expected style.

---

## Rate Limiting and API Best Practices

GitHub API has a rate limit of 5,000 authenticated requests per hour (~83 requests per minute). During rapid sprint execution with automation, workflows, and batch operations, exhausting the quota is a common failure mode.

### Backoff Policy

**Exponential backoff is mandatory** for any polling or retry logic:

```text
Initial delay: 30 seconds
Max delay: 90 seconds
Backoff multiplier: 1.5x
```

**Example:**

- Attempt 1: Wait 30s
- Attempt 2: Wait 45s
- Attempt 3: Wait 67.5s (capped at 90s)

**Reference implementation:** `scripts/rate-limit-backoff.ps1`

### Batch Operations Guidance

- **Max batch size:** 5 operations per 60 seconds
- **Delay between batches:** 10 seconds minimum
- **Example:** Running 50 workflow dispatches should take ≥ 10 minutes (5 dispatches × 60s + 9 × 10s delays)

### Workflow Dispatch Spacing

Avoid triggering multiple workflow runs in rapid succession:

- **Minimum spacing:** 60+ seconds between dispatch calls for the same workflow
- **Reason:** Each dispatch triggers GitHub actions, API logging, and repository polling, consuming quota and CI capacity
- **Best practice:** Use `gh workflow run` with `--ref` to specify branch, but always pause ≥ 60s before the next call

**Example:**

```powershell
# DON'T do this
gh workflow run build.yml --ref main
gh workflow run build.yml --ref main  # fired immediately — quota and CI waste

# DO this instead
gh workflow run build.yml --ref main
Start-Sleep -Seconds 60
gh workflow run build.yml --ref main
```

### `gh` CLI Best Practices

1. **Disable automatic retry logic** to control backoff yourself:

   ```powershell
   gh config set http.retries 0
   ```

2. **Check rate limit before batch operations:**

   ```powershell
   gh api rate_limit --jq '.rate.remaining'
   # If < 50: pause and wait; if < 100: warn
   ```

3. **Log rate limit headers** after each call:

   ```powershell
   # Extract from response metadata
   gh api repos/owner/repo/issues --jq '.[] | "\(.number): \(.url)"' \
     --header 'X-GitHub-Api-Version:2022-11-28'
   ```

### Rate Limit Header Logging

Always inspect these headers after API calls, especially in automation:

- **`X-RateLimit-Limit`** — Total requests allowed (5000 for authenticated)
- **`X-RateLimit-Remaining`** — Requests left in current window
- **`X-RateLimit-Reset`** — Unix timestamp when quota resets
- **`X-RateLimit-Used`** — Requests consumed this window

**Strategy:**

1. Log these headers in CI/CD logs for debugging
2. If `Remaining < 50`, pause and wait until `Reset` time
3. If `Remaining < 200`, log a warning and increase delay between operations

### Automation Safeguards

**Sprint execution checklist:**

- [ ] All polling loops implement exponential backoff (min 30s, max 90s)
- [ ] Workflow dispatch calls have 60+ second spacing
- [ ] Batch operations respect 5 per 60s limit
- [ ] Rate limit check (`gh api rate_limit`) runs before major operations
- [ ] CI logs capture rate limit headers (for post-mortem analysis)
- [ ] Manual testing validates backoff with `--dry-run` flags where available

### References

- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api?apiVersion=2022-11-28#rate-limiting)
- [gh CLI Rate Limit Docs](https://cli.github.com/manual/gh_api)
- Related issues: #451 (concurrency control), #443 (observed exhaustion)

---

## Asset Distribution

When an instruction or prompt file is maintained for BaseCoat's own internal use only
(governance rules, framework-specific patterns, memory indexes), it should **not** be
distributed to repos that adopt BaseCoat as a foundation.

Mark such files with `distribute: false` in their YAML frontmatter:

```yaml
---
description: "..."
applyTo: "**/*"
distribute: false
---
```

Sync scripts (`sync.ps1`, `sync.sh`) skip any instruction file containing
`distribute: false` when copying assets to downstream repositories.

Files currently marked `distribute: false`:

- `instructions/basecoat-20-lang-governance.instructions.md` — BaseCoat repo-governance rules
- `instructions/basecoat-10-core-enterprise-configuration.instructions.md` — enterprise setup guidance
- `instructions/basecoat-10-core-hrm-execution.instructions.md` — internal execution hierarchy
- `instructions/basecoat-50-security-token-economics.instructions.md` — cost-routing rules for this repo
- `instructions/basecoat-10-core-memory-index.instructions.md` — hot-cache memory index

When adding a new instruction, ask: "Should downstream repos receive this?" If the
answer is no (it references BaseCoat tooling, sprints, or internal conventions), add
`distribute: false`.

---

## Questions

Open an issue with the `question` label. Do not DM maintainers for things that belong in the open.

<!-- markdownlint-enable MD009 MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->
