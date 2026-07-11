# Sprint Planner — Detail Reference

## Agent Role Mapping

| Work Nature | Recommended Agent |
|---|---|
| API, service, data access | `backend-dev` |
| UI, components, accessibility | `frontend-dev` |
| Integration, message contracts | `middleware-dev` |
| Schema, migration, query | `data-tier` |
| Test strategy, charters | `manual-test-strategy` |
| Code review | `code-review` |
| Branch merging | `merge-coordinator` |
| Exploratory testing | `exploratory-charter` |
| Automation candidates | `strategy-to-automation` |
| Cross-cutting or unclear | flag for human decision |

## Milestone Creation Commands

```bash
SPRINT_TITLE="Sprint <N>"
MILESTONE_NUMBER=$(gh api "repos/<owner>/<repo>/milestones?state=all&per_page=100" \
  --jq ".[] | select(.title == \"$SPRINT_TITLE\") | .number" | head -n 1)

if [ -z "$MILESTONE_NUMBER" ]; then
  MILESTONE_NUMBER=$(gh api "repos/<owner>/<repo>/milestones" \
    -f title="$SPRINT_TITLE" --jq ".number")
fi
```

## GitHub Project Creation Commands

```bash
PROJECT_NUMBER=$(gh project list --owner <owner> --limit 200 --format json \
  --jq ".projects[] | select(.title == \"Sprint <N>\") | .number" | head -n 1)

if [ -z "$PROJECT_NUMBER" ]; then
  gh project create --owner <owner> --title "Sprint <N>" >/dev/null
  PROJECT_NUMBER=$(gh project list --owner <owner> --limit 200 --format json \
    --jq ".projects[] | select(.title == \"Sprint <N>\") | .number" | head -n 1)
fi
```

## Issue Body Template

```markdown
## Work Item

**Sprint:** <N>
**Wave:** <wave number>
**Agent:** <recommended agent role>
**Priority:** <high | medium | low>

### Description
<what this work item delivers>

### Dependencies
- **Blocked by:** <list of issue titles or 'none'>
- **Blocks:** <list of issue titles or 'none'>

### Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

### Notes
<constraints, risks, or context>
```

## Sprint Board Output Format

### Wave Dependency Map

```text
Wave 1 (parallel):  #A, #B, #C
Wave 2 (parallel):  #D (blocked by #A), #E (blocked by #B)
Wave 3 (sequential): #F (blocked by #D, #E)
```

Visual graph example:

```text
#A --> #D --+
#B --> #E --+--> #F
#C         |
```

### Issue Summary Table

| Issue | Title | Wave | Agent | Priority | Blocked By | Blocks |
|-------|-------|------|-------|----------|------------|--------|

### Sprint Metrics

- Total issues, wave count, max parallel width
- Critical path (longest sequential chain)
- Unassigned items (flagged for human decision)

### Risk Flags

- Dependency cycles
- Single points of failure (one item blocking many downstream)
- Underspecified acceptance criteria
- Items spanning multiple agent domains
