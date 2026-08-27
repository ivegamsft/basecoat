# Product Manager — Templates and Prioritization Detail

Supporting detail for [`agents/basecoat-10-core-product-manager.agent.md`](../basecoat-10-core-product-manager.agent.md).

## User Story Template

Create user stories following the **INVEST** criteria (Independent, Negotiable, Valuable, Estimable, Small, Testable).

```markdown
### User Story

**As a** <persona>,
**I want** <capability>,
**So that** <business value>.

#### Acceptance Criteria

- [ ] Given <precondition>, when <action>, then <expected result>
- [ ] Given <precondition>, when <action>, then <expected result>
- [ ] <Non-functional requirement if applicable>

#### Notes

- Dependencies: <list any blockers or upstream work>
- Out of scope: <explicitly excluded items>
```

Break epics into multiple stories. Each story should be deliverable in a single sprint. For each story, write
acceptance criteria in Given/When/Then format, covering the happy path, edge cases, and error states, and
include non-functional requirements (performance, accessibility) where relevant.

## Prioritization Frameworks

**RICE Scoring:**

| Factor | Definition |
| --- | --- |
| **Reach** | How many users/events per quarter |
| **Impact** | Score 0.25 (minimal) to 3 (massive) |
| **Confidence** | Percentage (100% = high, 50% = low) |
| **Effort** | Person-sprints to deliver |

`RICE Score = (Reach × Impact × Confidence) / Effort`

**MoSCoW Classification:**

| Category | Meaning |
| --- | --- |
| **Must have** | Non-negotiable for this release |
| **Should have** | Important but not critical |
| **Could have** | Nice to have if time permits |
| **Won't have** | Explicitly deferred |

## GitHub Issue Filing

When creating issues for user stories:

```bash
gh issue create \
  --title "feat: <short story title>" \
  --label "enhancement,user-story" \
  --repo "${OWNER}/${REPO}" \
  --body-file - <<'ISSUE_BODY'
<full user story with acceptance criteria>
ISSUE_BODY
```

- One issue per user story (not per epic)
- Link related issues with "Related to #XX" in the body
- Add priority label: `priority:critical`, `priority:high`, `priority:medium`, or `priority:low`

## Output Format

```markdown
## Product Requirements — <Feature Name>

### Problem Statement
<concise problem description>

### User Stories
<numbered list of stories with acceptance criteria>

### Prioritization
<RICE table or MoSCoW classification>

### Roadmap Recommendation
<sprint/release placement with rationale>

### Risks & Assumptions
- <risk or assumption>

### Stakeholder Summary
<2-3 sentence executive summary>
```
