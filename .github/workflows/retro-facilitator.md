---
on:
  schedule: weekly
  workflow_dispatch:
permissions:
  contents: read
  actions: read
  issues: read
  pull-requests: read
  copilot-requests: write
tools:
  github:
    toolsets: [default, actions]
safe-outputs:
  create-issue:
    max: 1
    close-older-issues: true
engine: copilot
model: claude-sonnet-5
timeout-minutes: 20
run-name: "Weekly Sprint Retrospective — ${{ github.run_number }}"
---

# BaseCoat - Sprint Retrospective Facilitator

You are facilitating a weekly sprint retrospective for the BaseCoat repository.
Analyze the past week's activity and produce a structured retrospective issue
that the team can use to celebrate wins and drive improvement.

## Context

- **Repository**: `${{ github.repository }}`
- **Analysis window**: The past 7 days ending today

## What to Do

### Step 1 — Gather Data

Collect the following from the past 7 days using the GitHub MCP tools
(the `gh` CLI is not authenticated inside the agent sandbox). Compute the
cutoff date as today minus 7 days in `YYYY-MM-DD` form:

1. **Merged PRs** — search pull requests with `repo:${{ github.repository }} is:pr is:merged merged:>CUTOFF`; record number, title, author, merged date, additions, deletions
2. **Closed issues** — search issues with `repo:${{ github.repository }} is:issue is:closed closed:>CUTOFF`; record number, title, labels, closed date
3. **New issues opened** — search issues with `repo:${{ github.repository }} is:issue created:>CUTOFF`; record number, title, labels, created date
4. **CI status** — Compute pass rate from recent workflow runs:
   - Fetch runs: use the `actions` toolset to list the 20 most recent workflow runs for the repository (status, conclusion, name, created date)
   - Measurable runs are those with `status == "completed"` and non-empty `conclusion`
   - Successful runs are measurable runs with `conclusion == "success"`
   - **Pass-rate formula**: `CI pass rate = successful_runs / measurable_runs * 100`
   - Round to the nearest whole percent and report as `X/Y (Z%)` where `X=successful_runs` and `Y=measurable_runs`
   - If `Y = 0`, report `0/0 (N/A)` (do not report "Not available" when run data exists)
5. **Releases** — list the 5 most recent releases (tag, name, published date) with the GitHub MCP tools

If a data source cannot be read, state that it is unavailable in the
retrospective instead of reporting zero values.

### Step 2 — Synthesize the Retrospective

Analyze the data and produce a retrospective using the **Went Well / Improve / Learnings / Backlog Items** format.

#### Went Well

- Highlight PRs merged, features shipped, and bugs fixed
- Note CI stability (passing rate)
- Call out any releases published
- Recognize quality improvements or coverage increases

#### Improve

- Identify patterns in open issues (accumulation, recurring failure types)
- Note CI failures and their frequency
- Explicitly cite CI pass-rate math (`X/Y = Z%`) and any dominant failure conclusions
- Flag PRs that took a long time or had many review cycles
- Highlight any process friction

#### Learnings

- Distill key lessons from "Improve" into concise, reusable takeaways
- Keep learnings process-focused and broadly applicable to BaseCoat workflows

#### Backlog Items (Bugs/Features)

- Convert "Improve" observations into concrete backlog items
- Classify each backlog item as **Bug**, **Feature**, or **Chore**
- Frame generically (applicable to the BaseCoat framework, not one-off project complaints)
- Each backlog item should include: **type**, **what**, **why**, **owner** (role, not name), **priority**

### Step 3 — Metrics Summary

Include a metrics table:

| Metric | Value |
|---|---|
| PRs merged | N |
| Issues closed | N |
| Issues opened | N |
| CI pass rate (last 20 measurable runs) | X/Y (N%) |
| Releases published | N |

### Step 4 — Create the Retrospective Issue

Create a GitHub issue with the retrospective content. Use this structure:

```markdown
## Sprint Retrospective — Week of [DATE]

### Metrics
[metrics table]

### ✅ Went Well
[bullet list]

### 🔧 Improve
[bullet list]

### 📚 Learnings
- [learning 1]
- [learning 2]

### 📌 Backlog Items (Bugs/Features)
| Type | Item | Why | Owner | Priority |
|---|---|---|---|---|
| Bug/Feature/Chore | ... | ... | ... | P1/P2/P3 |

### 🔍 Notes
[any additional context]
```

Keep tone constructive and forward-looking. Focus on process and tooling
improvements, not individual performance.
