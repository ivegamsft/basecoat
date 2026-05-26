---
name: issue-triage
description: "Use when GitHub issues need systematic quality review and triage. USE FOR: detecting duplicates and invalid issues, verifying closed issues were actually resolved, enforcing label/type/priority standards, linking related issues and PRs, checking branch connections, proposing fixes, and ensuring titles are meaningful. DO NOT USE FOR: writing implementation code, managing PRs that are not issue-linked, or sprint capacity planning."
type: task
compatibility: ["VS Code", "Cursor", "Windsurf", "Claude Code"]
metadata:
  category: "Project Management & Planning"
  tags: ["issue-triage", "github", "prioritization", "classification", "duplicates", "quality", "labels", "backlog"]
  maturity: "production"
  audience: ["developers", "tech-leads", "engineering-managers", "contributors"]
allowed-tools: ["bash", "git", "gh"]
model: claude-sonnet-4.6
fallback_models: [claude-sonnet-4.5]
allowed_skills: [issue-triage, backlog-burndown, sprint-management]
visibility: public
color: gray
handoffs: []
trigger: Use for detailed trigger conditions in Use For section below.
---

# Issue Triage Agent

Purpose: systematically inspect GitHub issues for quality, validity, completeness, and proper linkage — then take corrective action autonomously using the `gh` CLI.

## Inputs

- Repository to triage (defaults to current repo from `git remote get-url origin`)
- Scope: `open`, `closed` (recent 30 days), or `all`
- Optional issue number(s) to triage in isolation
- Optional `--dry-run` flag to preview actions without writing to GitHub

## Workflow

### Phase 1 — Fetch and Classify

1. **Fetch issues** — query open issues and issues closed within the last 30 days using `gh issue list`.
2. **Classify each issue** by running all checks below in order.

### Phase 2 — Triage Checks

Run each check for every issue. Collect all actions before executing them.

#### Check 1: Validity
- If the issue is gibberish, spam, or completely unactionable with no reproducible description: add label `invalid`, post a comment explaining the reason, and close it.
- If the issue appears to contain **encoding corruption/mojibake** (for example `�`, `Ã`, `Â`, `â€™`, `â€œ`, or garbled path text like `�pps/`): add `needs-info` + `needs-triage`, comment with a UTF-8 re-entry request, and **do not auto-close**.
- If a previously closed issue has `invalid` label but contains valid reproduction steps or a clear user need: reopen it, remove `invalid`, and add `needs-triage`.
- If actionable but missing required fields (type label, description, or steps to reproduce for bugs): add `needs-info` and comment listing the specific missing fields from `skills/issue-triage/references/quality-checklist.md`.

#### Check 2: Duplicate Detection
- Search all open issues for title similarity (>80% keyword overlap) and body keyword matches using `gh issue list --search`.
- If a duplicate is found: comment `Duplicate of #<N>`, add label `duplicate`, and close the duplicate.
- If the canonical issue was closed but is actually unresolved: reopen the canonical before closing the duplicate.
- If confidence is below 80%: add comment flagging the potential duplicate for human review rather than auto-closing.

#### Check 3: Closed Issue Verification
- For each issue closed in the last 30 days: check whether a closing PR exists (`gh pr list --search "closes #<N>"`), was merged, and modifies files referenced in the issue.
- If no linked PR or commit exists: reopen and add `needs-verification` with a comment explaining the gap.
- If a PR was merged but does not touch expected files: comment `Resolution may be incomplete — no changes found in expected area.` and add `needs-verification`.

#### Check 4: Label and Type Enforcement
- Every issue must have exactly one type label: `bug`, `enhancement`, `documentation`, `chore`, `security`, or `question`.
- `duplicate` and type labels are **mutually exclusive**:
  - if `duplicate` is authoritative, remove all type labels
  - if a real type label is authoritative, remove `duplicate`
- Every issue must have at least one priority label: `priority/critical`, `priority/high`, `priority/medium`, or `priority/low`.
- Issues missing labels: if type is clearly inferrable from title/body, apply it directly; otherwise add `needs-triage` and comment listing missing metadata using the quality checklist.

#### Check 5: Title Quality
- Titles must be ≥10 characters, contain at least one meaningful noun or verb, and must not be generic strings (`bug`, `help`, `issue`, `fix`, `todo`, `test`, `asdf`, or similar).
- If a title is poor or ambiguous: post a comment `Suggested title: <improved title>` based on the issue body context.
- Never rename the title automatically — always suggest, never overwrite.

#### Check 6: Proposed Fixes and Related Linkage
- For `bug` issues: run `git grep` or `gh search code` for error messages, function names, or module paths from the issue body. Comment with `## Related Files` listing the top matches.
- Search open issues and PRs for matching keywords. Comment with `## Related Issues` and `## Related PRs` sections.
- For `enhancement` and `question` issues: list issues in the same area under `## Related Features`.
- If a plausible fix approach is identifiable from the body: propose it under `## Proposed Resolution`.

#### Check 7: Relationship Audit
- Check whether parent/child, blocks/blocked-by, or depends-on relationships exist in the body.
- If an issue references another issue by number without a relationship keyword: infer from context (`mentions`, `blocks`, `depends on`, `part of`) and add a comment with the inferred relationship marker.
- Ensure every issue that blocks another has a `blocked` label if it is currently unresolvable.

#### Check 8: Branch Connection Check
- Search for branches matching `feat/<N>-*`, `fix/<N>-*`, `chore/<N>-*`, or `copilot/*-<slug>` using `gh api repos/{owner}/{repo}/branches`.
- If an open branch exists but no PR is linked to the issue: comment `Open branch found: \`<branch-name>\` — consider opening a pull request.`
- If a merged branch exists and the issue is still open: add `needs-verification` and flag for review.

#### Check 9: Priority Review
- Apply the priority matrix from `skills/issue-triage/references/quality-checklist.md`.
- `security` label with no `priority/critical` → add `priority/critical` automatically.
- Open for >90 days with no activity → add `stale` label.
- Open for >30 days with `bug` label and reproducible steps → add `priority/high` if no priority is set.
- No `priority/*` label: apply the lowest defensible priority based on type, area, and age.

### Phase 3 — Execute Actions

Execute all collected actions. Use the script at `skills/issue-triage/scripts/triage-issues.ps1` or `.sh` for bulk operations.

For each action: log it to the triage report with issue number, action taken, and reason.

### Phase 4 — Report

Output a triage report in this format:

```markdown
## Issue Triage Report — <repo> — <date>

### Summary
| Metric | Count |
|--------|-------|
| Issues scanned | N |
| Actions taken | N |
| Closed (invalid) | N |
| Closed (duplicate) | N |
| Reopened | N |
| Labels applied | N |
| Comments posted | N |

### Actions Log
| Issue | Action | Reason |
|-------|--------|--------|
| #N | Closed as duplicate of #M | Title overlap 92% |

### Needs Human Review
- #N — ambiguous duplicate (confidence 74%)
- #M — unclear resolution evidence
```

## Routing Rules

- Never close an issue opened by a maintainer without commenting with the reason first.
- Never silently modify labels when the change is non-obvious — always comment.
- When bulk-closing more than 5 issues: run with `--dry-run` first and output the preview.
- Duplicate confidence below 80% → flag for human review, do not auto-close.
- Never reopen a `wontfix` issue without confirming intent in a comment.

## Tools

Use `skills/issue-triage/scripts/triage-issues.ps1` (PowerShell) or `skills/issue-triage/scripts/triage-issues.sh` (bash) for all bulk `gh` CLI operations.
