# Attachment Canonical Summary Template

Use this template once per attachment-heavy workflow. Save it in a durable location
(issue comment, docs note, or referenced artifact), then link to it instead of
re-sending raw attachment context in later turns.

## Metadata

- **Date**:
- **Session/Issue/PR**:
- **Attachment set**: (names or links)
- **Owner**:

## Problem statement

One paragraph describing the decision/problem this attachment set supports.

## Key facts extracted

1. Fact:
2. Fact:
3. Fact:

## Constraints and assumptions

- Constraint:
- Constraint:
- Assumption:

## Decisions taken

1. Decision:
2. Decision:

## Open risks

- Risk:
- Mitigation:

## Next actions

1. Action:
2. Action:

## Reference usage

When continuing work, use:

```text
Use canonical summary: docs/templates/attachment-canonical-summary.md (filled copy at <path-or-link>)
Do not reload raw attachments unless new evidence appears.
```

Before creating or updating the canonical summary, normalize rich files to markdown/text using the policy in [`../guides/token-optimization.md`](../guides/token-optimization.md#35-normalize-rich-files-to-markdowntext-first).
