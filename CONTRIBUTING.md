# Contributing to basecoat

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

## Adding Agents, Skills, and Instructions

- **Agents** go in `agents/`. Use existing agents as templates.
- **Skills** go in `skills/<skill-name>/`. Every skill needs a `SKILL.md`.
- **Instructions** go in `instructions/`. Every instruction needs frontmatter with `description` and `applyTo`.
- **Templates** go in `docs/templates/`.

All new agents, skills, and instructions require an issue before implementation.

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
| `prd-spec-gate` | `prd-spec-gate.yml` | Requires PRD/spec links for high-change or risky PRs |
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

---

## Questions

Open an issue with the `question` label. Do not DM maintainers for things that belong in the open.
