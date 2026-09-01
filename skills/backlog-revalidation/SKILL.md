---
name: backlog-revalidation
compatibility: [copilot-chat, copilot-coding-agent, github-copilot-cli]
description: "Use for evidence-based revalidation of older issues and pull requests. USE FOR: classify old issues as still needed, superseded, resolved, duplicate, or recurring; revalidate stale PRs against current code; run oldest-first or scheduled report-only reviews. DO NOT USE FOR: closing items because they are old, sprint prioritization, or treating text similarity as proof of duplication."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
---

# Backlog Revalidation

Produce a report-first recommendation. Age and inactivity are candidate
filters, never disposition evidence.

## Modes

- **Single:** revalidate one issue or pull request.
- **Batch:** oldest-first review with configurable age, type, labels, and exclusions.
- **Scheduled:** report-only. Never mutate in scheduled mode.

## Classification

`still-needed` | `needs-modification` | `superseded` | `recurring` |
`already-resolved` | `duplicate` | `not-needed` | `insufficient-evidence`

Schema and decision policy:
[`references/classification-contract.md`](references/classification-contract.md)

## Workflow

1. Bound the mode, item type, age filter, and exclusions.
2. Collect structured evidence before any model judgment: metadata, links,
   closing keywords, merged PRs, commits, current code, tests, workflows,
   docs, ADRs, releases, and later similar items.
3. Classify with citations and confidence. Text similarity is a signal, not proof.
4. Recommend comment, label, close, reopen, or human-review. Do not rewrite
   author intent; for `needs-modification` propose revised title/scope only.
5. Hand issue mutations to `issue-triage`. Hand PR mutations to
   `orphaned-pr-cleanup`. Recurrence uses one canonical tracker plus episode links.

## Guardrails

- Do not auto-close solely because an item is stale.
- Auto-action only for high-confidence, evidence-linked
  `duplicate`, `superseded`, or `already-resolved` cases, and only when
  explicitly requested outside scheduled mode.
- Medium or low confidence goes to human review.
- Bulk mutation of more than five items requires dry-run first, then approval.
- Partial fixes, reverted PRs, and reopened product direction are
  `insufficient-evidence` or `needs-modification`, not resolved.

## Output

Return the evidence contract for every item, ranked recommendations, canonical
links, confidence, and an explicit mutation statement (`none` unless a
high-confidence action was requested).
