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

```
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
```
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
```
<type>: <short description> (closes #<issue-number>)
```

**Examples:**
```
feat: governance framework documentation (closes #43)
fix: commit-msg hook glob pattern (closes #17)
```

---

## Commit Message Format

```
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

## Questions

Open an issue with the `question` label. Do not DM maintainers for things that belong in the open.
