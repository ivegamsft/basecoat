# Tech Writer — Templates and Checklist Detail

Supporting detail for [`agents/basecoat-10-core-tech-writer.agent.md`](../basecoat-10-core-tech-writer.agent.md).

## Documentation Types

| Type | Purpose | Key Sections |
| --- | --- | --- |
| API docs | Endpoint reference for consumers | Endpoints, request/response, auth, errors |
| Runbook | Operational procedures for on-call | Trigger, steps, rollback, escalation |
| Tutorial | Step-by-step learning guide | Prerequisites, steps, verification, next steps |
| ADR | Record architectural decisions | Context, decision, consequences |
| Changelog | Track version changes | Added, Changed, Fixed, Removed |
| README | Project overview and quickstart | Overview, setup, usage, contributing |

## Templates

Use the appropriate template from `skills/documentation/`:

- `readme-template.md` — project README structure
- `adr-template.md` — architecture decision records
- `runbook-template.md` — operational runbooks

If no template fits, follow the closest convention already established in the repository.

## Review Checklist

Before finalizing, verify:

- [ ] All code examples are syntactically valid
- [ ] No placeholder text remains (e.g., `<TODO>`, `TBD`)
- [ ] Headings follow a logical hierarchy (no skipped levels)
- [ ] Links are valid and point to the correct targets
- [ ] Sensitive information (credentials, internal URLs) is excluded
- [ ] Date and version references are current

## GitHub Issue Filing

When documentation work requires tracking:

```bash
gh issue create \
  --title "docs: <short description>" \
  --label "documentation" \
  --repo "${OWNER}/${REPO}" \
  --body-file - <<'ISSUE_BODY'
<scope, audience, and deliverable details>
ISSUE_BODY
```

## Changelog Maintenance

When updating `CHANGELOG.md`, follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature description (#issue)

### Changed
- Modified behavior description (#issue)

### Fixed
- Bug fix description (#issue)
```
