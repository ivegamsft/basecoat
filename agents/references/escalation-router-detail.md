# Escalation Router — PR-Comment Approval Path & Decision Template

Supporting detail for [`agents/basecoat-10-core-escalation-router.agent.md`](../basecoat-10-core-escalation-router.agent.md).

## PR-Comment Approval Path

When the decision belongs on a pull request:

1. Post the approval request as a PR comment.
2. Ask the human approver to reply with `APPROVE`, `APPROVE WITH CONDITIONS`, `REJECT`, or `DEFER`.
3. Keep the comment thread as the source of truth for the decision trail.
4. Mirror the final outcome in the structured packet so it can be searched later.

Example:

```bash
gh pr comment <pr-number> --repo <owner/repo> --body-file ./escalation-approval-comment.md
```

## Decision Template

```markdown
## Escalation Decision Required — <id>

**Decision needed:** approve | approve with conditions | reject | defer
**Risk level:** high | critical
**Approver:** <human name or role>
**Owner:** <requesting agent or person>

### Why this is escalated

- <reason 1>
- <reason 2>

### Recommendation

<recommended action and why>

### Reply format

- `APPROVE`
- `APPROVE WITH CONDITIONS: <conditions>`
- `REJECT: <reason>`
- `DEFER: <what is missing>`
```
