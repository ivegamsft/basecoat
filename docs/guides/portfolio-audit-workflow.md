# Portfolio Audit Workflow

Use this workflow to audit project hygiene across issues and pull requests with
deterministic outputs:

1. No obvious duplicates left open.
2. Every issue has category and priority metadata.
3. Dependency edges are explicit (`blocked by` / `depends on`).
4. Work is grouped into meaningful feature clusters.
5. Active sprint/project link is visible in repository docs.

## Intent

Use the `portfolio:` prefix for this workflow.

Example:

```text
portfolio: audit issues and PRs for duplicates, categorize, set dependencies, group by feature, and ensure project link
```

## Inputs

- Target repo (`owner/repo`)
- Optional sprint or date window
- Label taxonomy source (`docs/reference/label-taxonomy.md` when present)
- Existing project/milestone conventions (`Sprint <N>`)

## Phase 1: Issue hygiene and duplicate cleanup

Primary route: `@issue-triage`

Goals:

- Detect and close high-confidence duplicate issues.
- Normalize type and priority labels.
- Flag ambiguous duplicates for human review.

Suggested commands:

```bash
gh issue list --state open --limit 500 --json number,title,labels,createdAt,updatedAt
gh issue list --state open --search "is:issue sort:updated-asc" --limit 200 --json number,title,labels
```

Outputs:

- Updated issue labels and triage comments
- Duplicate closure list
- Human-review queue for low-confidence duplicate matches

## Phase 2: PR hygiene and stale ownership cleanup

Primary route: `@orphaned-pr-cleanup`

Goals:

- Classify stale PRs (revive, close, escalate).
- Identify PRs that should map into feature clusters but lack metadata.

Suggested commands:

```bash
gh pr list --state open --limit 300 --json number,title,labels,isDraft,updatedAt,author,reviewDecision
gh pr list --state merged --limit 300 --json number,title,labels,mergedAt,author
```

Outputs:

- PR triage classification
- Reviewer/owner action list
- Missing-label report for merged PRs

## Phase 3: Dependency mapping and issue traceability

Primary route: `@issue-triage` plus `@sprint-planner`

Goals:

- Verify dependency links exist for blocked work.
- Ensure blocked work includes explicit issue-level dependency links.

Suggested checks:

```bash
gh issue list --state open --limit 500 --json number,title,labels,body \
  | jq '.[] | select((.body // "" | test("blocked by|depends on"; "i")) or ((.labels // []) | map(.name) | any(test("blocked|dependency"; "i")))) | .number'
```

Outputs:

- Dependency edge map
- Dependency-link update actions
- Unlinked dependency gap list

## Phase 4: Feature grouping and significance gate

Primary route: `@sprint-project-mapper`

Goals:

- Cluster issues and PRs into meaningful features.
- Keep residual/noise buckets out of top-line metrics.

Significance defaults:

- Breadth: `issues >= 5` or `merged_prs >= 3`
- Activity: `loc_changed >= 200` or `activity_span_days >= 7` or explicit sprint/milestone tag

Outputs:

- Feature group map
- Split/merge debate decisions with confidence
- Residual group report

## Phase 5: Project linking and tracking integrity

Primary route: `@sprint-planner`

Goals:

- Reuse or create canonical `Sprint <N>` milestone and project.
- Add grouped issues to project and initialize status.
- Ensure the active project link is present in repo docs.

Suggested commands:

```bash
gh project list --owner <owner> --limit 200 --format json
gh project view <number> --owner <owner> --format json
```

Required doc check:

- Confirm at least one canonical active project link is documented in
  `docs/` (for example a sprint operations or workflow reference page).

## Output contract

Return a single report with:

1. Summary counts (issues scanned, PRs scanned, duplicates closed, dependencies linked, groups finalized).
2. Feature group table (`Group`, `Issues`, `PRs`, `LOC`, `Median Cycle Time`).
3. Dependency table (`Issue`, `Depends On`, `Blocked By`, `Status`).
4. Project tracking section (milestone name, project name, project-link doc path).
5. Carry-forward queue for unresolved ambiguities.

## Failure handling

- If duplicate confidence is below threshold, do not auto-close.
- If dependency direction is ambiguous, mark for human triage.
- If no project exists and creation is disallowed, report as blocking gap.
- If required metadata conventions are missing, log a governance issue and stop before final grouping.
