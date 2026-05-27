---
on:
  issues:
    types: [opened]
  workflow_dispatch:
permissions:
  contents: read
  issues: read
  pull-requests: read
safe-outputs:
  add-labels:
  add-comment:
engine: copilot
timeout-minutes: 20
run-name: "Issue Triage — #${{ github.event.issue.number }}"
---

# Issue Triage Agent

You are triaging a newly opened GitHub issue. Your job is to classify it,
assign a priority, apply labels, and post a concise triage summary comment.

## Policy Contract

This workflow enforces the skill contract defined in:

- `skills/issue-triage/references/quality-checklist.md` — label taxonomy, type definitions, priority matrix, and minimum-bar quality checks
- `skills/issue-triage/references/triage-workflow.md` — step-by-step decision trees for each triage check

All classification decisions must conform to those references. When in doubt, consult the reference files.

## Context

- **Issue number**: `${{ github.event.issue.number }}`
- **Issue title**: `${{ github.event.issue.title }}`
- **Repository**: `${{ github.repository }}`

Fetch the full issue details using:

```bash
gh issue view ${{ github.event.issue.number }} --repo ${{ github.repository }} --json number,title,body,author,labels,createdAt
```

## What to Do

### Step 1 — Minimum-Bar Quality Check

Before classifying, perform a minimum-bar quality check per `skills/issue-triage/references/quality-checklist.md`:

- Title is at least 10 characters and contains a meaningful word.
- Body contains at least 50 characters of meaningful text.
- No mojibake or encoding corruption present.
- For bugs: expected vs actual behavior or error message is present.
- For enhancements: a problem statement or user story is present.

If the issue fails the minimum-bar quality check, add `needs-triage` and comment listing what is missing.

### Step 2 — Classify the Issue Type

Determine the issue type based on title, body, and labels already present.
Apply exactly one type label per the taxonomy in `skills/issue-triage/references/quality-checklist.md`:

- **bug** — existing behavior differs from documented or expected behavior
- **enhancement** — new capability or improvement to an existing feature
- **documentation** — missing, incorrect, or out-of-date docs
- **chore** — non-user-facing maintenance: refactor, dependency upgrade, tooling
- **security** — vulnerability, secret exposure, injection risk, or CVE
- **question** — request for clarification, not a defect or feature

### Step 3 — Assign Priority

Use the priority taxonomy from `skills/issue-triage/references/quality-checklist.md`.
Apply exactly one priority label:

| Priority | Criteria |
|---|---|
| `priority:critical` | Service down, data loss, active security breach, CVE |
| `priority:high` | Major feature broken, significant user impact, no workaround |
| `priority:medium` | Minor feature issue, workaround exists, moderate user impact |
| `priority:low` | Cosmetic, nice-to-have, documentation gaps, low user impact |

Default to `priority:low` if no strong signal exists.

### Step 4 — Check for Duplicates

Use `gh issue list` to find issues with similar titles or content. If a clear
duplicate exists, apply the `duplicate` state label and note the original issue
number in your comment.

Enforce duplicate/type exclusivity: if `duplicate` is applied, remove any type
label (`bug`, `enhancement`, `documentation`, `chore`, `security`, `question`).
A `duplicate` issue must not carry a type label simultaneously.

### Step 5 — Apply Labels

Apply the appropriate type label AND priority label. Add `good-first-issue`
if the issue is well-scoped and approachable for new contributors.

### Step 6 — Post Triage Summary

Post a comment using this structure:

```markdown
## Issue Triage Summary

**Type**: [bug | enhancement | documentation | chore | security | question]
**Priority**: [priority:critical | priority:high | priority:medium | priority:low]

**Reasoning**: Brief explanation of classification and priority rationale.

**Quality check**: [passed | failed — list missing fields]

**Suggested next steps**:
- [ ] Step 1
- [ ] Step 2

**Duplicate of**: #N (if applicable)
```

Keep the comment factual and professional. Do not speculate beyond what the
issue content supports.
