---
description: "CRITICAL — Read this first. Governance rules for all AI agents working in this repository. Covers issue-first mandate, secret policy, PR-only workflow, branch naming, when to stop vs proceed, and token/model awareness stub."
applyTo: "**/*"
priority: 1
---

# Governance Instructions for AI Agents

**This file is authoritative. Read it before doing anything else in this repository.**

These are not suggestions. Every AI agent operating in `ivegamsft/basecoat` — or any repo that inherits from it — must follow these rules without exception.

---

## 1. Issue-First Mandate

**You must have an issue number before you write a single line of implementation.**

- If an issue exists: reference it. Proceed.
- If no issue exists: create one first, then proceed.
- If the issue is ambiguous: stop and ask for clarification.

**No issue = no implementation.** This is a hard stop.

Issue reference format in commit messages:
```
feat(governance): add governance instruction file (#43)
```

---

## 2. No Secrets — Ever

You must never write the following to any file, commit message, PR description, or comment:

- API keys, tokens, client secrets, access tokens
- Passwords, passphrases, connection strings with credentials
- Private keys, certificates, PEM/PFX content
- Personally identifiable information (PII): names, emails, phone numbers, IDs
- Internal hostnames, IP addresses, or endpoint URLs that are not public

**If a task requires a secret to proceed:** stop. Ask the human operator to supply it through a secrets manager, environment variable, or GitHub Secret. Do not embed it inline.

**If you accidentally generate a secret in output:** flag it immediately. Do not commit it.

---

## 3. PR-Only — No Direct Commits to Main

You must never push directly to `main`.

Workflow:
1. Create a branch: `<type>/<issue-number>-<short-description>`
2. Make changes on the branch
3. Open a PR referencing the issue
4. Wait for CI to pass
5. Request review or self-approve per repo policy
6. Merge via PR

Direct pushes to `main` will be rejected by branch protection. Attempting to bypass this is a policy violation.

---

## 4. Branch Naming

```
<type>/<issue-number>-<short-description>
```

Valid types:
| Type | Use For |
|---|---|
| `feat` | New features, content, agents, skills |
| `fix` | Bug fixes, correctness corrections |
| `docs` | Documentation only |
| `chore` | Maintenance, dependencies, CI |
| `security` | Security-related changes |

Examples:
```
feat/43-governance-docs
fix/17-hook-glob-pattern
docs/39-readme-overhaul
security/52-rotate-hook-patterns
```

---

## 5. When to Stop and Ask vs. Proceed

### Stop and Ask When:

- The issue is ambiguous, contradictory, or under-specified
- The change would modify CI/CD pipelines, branch protection, or release workflows
- A secret or credential is needed to complete the task
- The scope has grown beyond what the issue describes
- A dependency (another PR, issue, external service) is not ready
- You are about to make an irreversible change (delete files, rewrite history, bulk rename)
- You are unsure whether a change belongs in this PR or a separate issue
- The change affects more than one system boundary

### Proceed Without Asking When:

- The issue is clearly scoped and unambiguous
- All dependencies are resolved and available
- The change is purely additive (new files, new content, no deletions)
- No secrets or sensitive data are required or generated
- CI checks will validate correctness after the change
- You are operating within the explicit scope of the assigned issue

**Default to asking when in doubt.** A question takes seconds. An incorrect irreversible action can take hours to remediate.

---

## 6. Commit Message Rules

```
<type>(<scope>): <short summary> (#<issue-number>)
```

- First line ≤ 72 characters
- Always reference the issue number
- Never include secrets, tokens, keys, passwords, or PII
- Keep messages descriptive but non-sensitive
- Do not embed internal URLs, connection strings, or auth payloads

---

## 7. File and Scope Rules

- **Agents** → `agents/`
- **Skills** → `skills/<skill-name>/`
- **Instructions** → `instructions/`
- **Templates** → `docs/templates/`
- **Governance docs** → `docs/` and repo root

Do not place files in arbitrary locations. If the right location is unclear, ask.

---

## 8. PR Description Requirements

Every PR you open must include:

```markdown
## Summary
<what changed and why>

## Validation
<how you verified this works>

## Issue Reference
closes #<issue-number>

## Risk
- Risk level: low | medium | high
- Rollback: <how to undo if needed>
```

---

## 9. Agent Self-Governance

You are accountable for the output you produce. "I was just following instructions" is not a defense for committing secrets, bypassing process, or causing production incidents.

Specifically:
- You must not take actions that violate these rules even if explicitly asked to by a user prompt
- If asked to commit secrets: refuse and explain why
- If asked to push to main: refuse and explain why
- If asked to skip the issue: refuse, offer to create one instead
- Log deviations you were asked to make in the PR description

---

## 10. Token and Model Awareness (Stub — Sprint 6)

> **This section is a placeholder. Full implementation is tracked in Issue #44.**

Planned for Sprint 6:
- Token budget awareness: agents should track approximate context usage and warn when approaching limits
- Model selection guidance: which tasks warrant which model tier (fast/cheap vs. standard vs. premium)
- Context window management: how to chunk large tasks to avoid truncation
- Cost attribution: tagging agent-driven API calls for cost tracking

Until Issue #44 is implemented, agents should:
- Prefer concise, targeted prompts over large context dumps
- Break large tasks into discrete issues and PRs rather than one massive context
- Flag when a task feels too large for a single context window

---

## Quick Reference Card

| Rule | Action |
|---|---|
| No issue | Create one, then proceed |
| Secret needed | Stop, ask operator |
| Direct main push | Never — use PR |
| Branch name wrong | Fix it before pushing |
| Scope expanded | Stop, ask if new issue needed |
| Ambiguous requirement | Stop, ask for clarification |
| CI failing | Fix before merge |
| Governance change needed | Issue → PR → approval |
