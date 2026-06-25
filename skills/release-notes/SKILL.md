---
name: release-notes
compatibility: [github-copilot-cli]
description: "Use when drafting or updating release notes from commits, pull requests, tags, waves, or sprints. USE FOR: create release notes for a version, summarize changes since a tag, generate notes by wave/sprint labels, produce internal or customer-facing changelog drafts, and structure upgrade notes with traceability. DO NOT USE FOR: release readiness audits, deployment execution, rollback operations, or post-release production incident troubleshooting."
---
# Release Notes Skill

Generate release notes from git/PR history with traceability.
Prefer `wave:*` / `sprint:*` labels over Projects/Milestones.

## USE FOR

- Drafting release notes for a version, wave, or sprint.
- Summarizing merged PRs and commits in a version range.
- Generating notes scoped by PR labels such as `wave:*` and `sprint:*`.
- Creating internal or customer-facing release notes from templates.
- Capturing breaking changes and upgrade notes.

## DO NOT USE FOR

- Release readiness audits or compliance checks.
- Executing deployment, publish, or rollback actions.
- Incident debugging or backlog triage.

## Workflow

1. Resolve scope: tag range, PR list, or labels.
2. For wave/sprint runs, filter PRs by `wave:*` / `sprint:*` first.
3. Collect evidence from commits, PRs, and linked issues.
4. Render notes from template and mark uncertain items `Needs confirmation`.

## Wave and Sprint Binding

Use this contract to keep release-note grouping stable:

- Primary keys: PR labels `wave:<id>` and `sprint:<id>`.
- Recommended policy: require one of these labels on PRs merged to main.
- Projects and Milestones are secondary hints.
- If labels are missing, group by merge window and mark `Needs confirmation`.

## Output Contract

Always output: Highlights, Breaking changes, Fixes and improvements, Known issues, Upgrade notes, Contributors.
Include metadata at top: Version/range, Wave (if present), Sprint (if present).

Each item should include traceability (PR number, commit SHA, or issue link).

## Guardrails

- Never invent PRs, issues, or fixes.
- Prefer customer-safe wording for external notes.
- When evidence is incomplete, flag for confirmation.

## Reference Files

- [`references/templates/internal.md`](references/templates/internal.md)
- [`references/templates/external.md`](references/templates/external.md)
- `scripts/validate-release-notes.ps1` writes validation reports to `reports/release-notes/`


