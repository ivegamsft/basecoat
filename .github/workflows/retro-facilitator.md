---
on:
  schedule: weekly
  workflow_dispatch:
permissions:
  contents: read
  issues: read
  pull-requests: read
safe-outputs:
  create-issue:
    max: 1
    close-older-issues: true
engine: copilot
timeout-minutes: 20
run-name: "Weekly Sprint Retrospective — ${{ github.run_number }}"
---

# Sprint Retrospective Facilitator

You are facilitating a weekly sprint retrospective for the BaseCoat repository.
Analyze the past week's activity and produce a structured retrospective issue
that the team can use to celebrate wins and drive improvement.

## Context

- **Repository**: `${{ github.repository }}`
- **Analysis window**: The past 7 days ending today

## What to Do

### Step 1 — Gather Data

Collect the following from the past 7 days using `gh` CLI:

1. **Merged PRs** — `gh pr list --state merged --search "merged:>$(date -d '7 days ago' +%Y-%m-%d)" --json number,title,author,mergedAt,additions,deletions`
2. **Closed issues** — `gh issue list --state closed --search "closed:>$(date -d '7 days ago' +%Y-%m-%d)" --json number,title,labels,closedAt`
3. **New issues opened** — `gh issue list --state open --search "created:>$(date -d '7 days ago' +%Y-%m-%d)" --json number,title,labels,createdAt`
4. **CI status** — Compute pass rate from recent workflow runs:
   - Fetch runs: `gh run list --limit 20 --json status,conclusion,name,createdAt`
   - Measurable runs are those with `status == "completed"` and non-empty `conclusion`
   - Successful runs are measurable runs with `conclusion == "success"`
   - **Pass-rate formula**: `CI pass rate = successful_runs / measurable_runs * 100`
   - Round to the nearest whole percent and report as `X/Y (Z%)` where `X=successful_runs` and `Y=measurable_runs`
   - If `Y = 0`, report `0/0 (N/A)` (do not report "Not available" when run data exists)
5. **Releases** — `gh release list --limit 5 --json tagName,publishedAt,name`

### Step 2 — Synthesize the Retrospective

Analyze the data and produce a retrospective using the **Went Well / Improve / Action Items** format.

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

#### Action Items

- Convert "Improve" observations into concrete, time-boxed actions
- Frame generically (applicable to the BaseCoat framework, not one-off project complaints)
- Each action item should include: **what**, **why**, **owner** (role, not name), **priority**

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

### 📋 Action Items
| Action | Why | Owner | Priority |
|---|---|---|---|
| ... | ... | ... | P1/P2/P3 |

### 🔍 Notes
[any additional context]
```

Keep tone constructive and forward-looking. Focus on process and tooling
improvements, not individual performance.
