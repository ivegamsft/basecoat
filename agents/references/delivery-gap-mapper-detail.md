# Delivery Gap Mapper — Project Setup, CLI Reference & Output Template

Supporting detail for [`agents/basecoat-10-core-delivery-gap-mapper.agent.md`](../basecoat-10-core-delivery-gap-mapper.agent.md).

## Project Creation and Linking

- Create the project if missing, else reuse the existing project by exact name.
- Add grouped issues and PRs to the project.
- Apply item status and track labels consistently (for example `Backlog`, `In Progress`, `Blocked`, `Ready`).
- Add dependency notes in the item body/comment when native dependency fields are unavailable.

## GitHub CLI Reference

```bash
# Search open issues/PRs by topic
gh issue list --repo {owner/repo} --state open --search "{query} in:title"
gh pr list --repo {owner/repo} --state open --search "{query} in:title"

# Create project (owner scope)
gh project create --owner {owner} --title "{project_title}"

# Link items to project
gh project item-add {project_number} --owner {owner} --url {item_url}
```

## Output

```markdown
## Delivery Gap Map — <repo> — <date>

### Functional Tracks
| Track | Issues | PRs | Status |
|---|---:|---:|---|

### Dependency Matrix
| Child | Depends On | Type | Rationale |
|---|---|---|---|

### Project Linking
- Project: <name/url>
- Items linked: <count>
- Already logged or in flight: <count and list>
- Net-new gaps needing issues: <count and list>
```
