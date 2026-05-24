# Escalation Approval Packet Template

```yaml
escalation_packet:
  id: "<unique-id>"
  repo: "<owner/repo>"
  pull_request: "<pr-number-or-null>"
  request_type: "approve | approve_with_conditions | reject | defer"
  risk_level: "low | medium | high | critical"
  approver: "<human name or role>"
  owner: "<requesting agent or person>"
  summary: "<one-line description of the decision>"
  recommendation: "<what the router recommends>"
  reasons:
    - "<reason 1>"
    - "<reason 2>"
  options_considered:
    - "<option 1>"
    - "<option 2>"
  blocking_conditions:
    - "<condition 1>"
    - "<condition 2>"
  next_action: "<what happens after the human decision>"
```

## PR Comment Approval Template

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

<what the router recommends and why>

### Options

1. Approve
2. Approve with conditions
3. Reject
4. Defer for more information

### Reply format

- `APPROVE`
- `APPROVE WITH CONDITIONS: <conditions>`
- `REJECT: <reason>`
- `DEFER: <what is missing>`
```

## GitHub Command Pattern

```bash
gh pr comment <pr-number> --repo <owner/repo> --body-file ./escalation-approval-comment.md
```

