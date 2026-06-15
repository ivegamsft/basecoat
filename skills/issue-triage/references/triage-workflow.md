# Issue Triage Workflow

Step-by-step decision guide for each triage check. Use this as a reference when running the `issue-triage` agent or the triage scripts manually.

---

## 0. Before You Start

```bash
# Confirm you are authenticated
gh auth status

# Set target repo (defaults to current repo if inside a git clone)
export OWNER=$(gh repo view --json owner --jq '.owner.login')
export REPO=$(gh repo view --json name --jq '.name')
export DRY_RUN=false   # set to true to preview only
```

---

## Check 1: Validity

**Goal**: Remove noise and reopen wrongly closed valid issues.

### Decision Tree

```text
Issue exists?
├── Contains mojibake/encoding corruption (`�`, `Ã`, `Â`, `â€™`, `â€œ`)? → Flag: needs-info + needs-triage (do not auto-close)
├── Is body <20 chars or purely gibberish? → Close: invalid
├── Is it a duplicate of a spam pattern? → Close: invalid + comment
├── Is it a previously closed issue with valid repro? → Reopen + remove invalid label
└── Is it missing required fields?
    ├── Bug: needs steps-to-reproduce and expected/actual behavior → needs-info
    ├── Enhancement: needs problem statement → needs-info
    └── Otherwise: actionable as-is → proceed
```

### gh Commands

```bash
# Close invalid
gh issue close $N --comment "Closing as invalid: [reason]. If this is actionable, please reopen with steps to reproduce or a clear problem statement."
gh issue edit $N --add-label "invalid"

# Reopen valid
gh issue reopen $N --comment "Reopening: this issue contains valid reproduction steps that were not addressed before closure."
gh issue edit $N --remove-label "invalid" --add-label "needs-triage"

# Flag needs-info
gh issue edit $N --add-label "needs-info"
gh issue comment $N --body "This issue needs more information before it can be triaged:\n- [ ] Steps to reproduce\n- [ ] Expected vs actual behavior\n- [ ] Environment details"
```

---

## Check 2: Duplicate Detection

**Goal**: Consolidate duplicate issues to the canonical tracker.

### Detection Method

1. Extract key terms from the title (strip stop words, keep nouns/verbs/error codes).
2. Search with `gh issue list --search "<terms>"`.
3. Calculate token overlap between titles.
4. If overlap >80%: duplicate. If 50–80%: possible duplicate (flag for human review).

### gh Commands

```bash
# Search for potential duplicates
gh issue list --state open --search "$SEARCH_TERMS" --json number,title,state

# Mark as duplicate and close
gh issue edit $NEW --add-label "duplicate"
# Enforce duplicate/type exclusivity
gh issue edit $NEW --remove-label "bug" --remove-label "enhancement" --remove-label "documentation" --remove-label "chore" --remove-label "security" --remove-label "question"
gh issue comment $NEW --body "Duplicate of #$CANONICAL — closing in favor of the original tracker.\nAll updates should go to #$CANONICAL."
gh issue close $NEW --reason "not planned"

# If canonical was wrongly closed, reopen it first
gh issue reopen $CANONICAL --comment "Reopening as the primary tracker. A duplicate (#$NEW) was filed while this was closed."
```

---

## Check 3: Closed Issue Verification

**Goal**: Catch issues closed without actual resolution.

### Detection Method

1. List issues closed in the last 30 days.
2. For each: search for PRs that reference it (`closes #N`, `fixes #N`, `resolves #N`).
3. If a merged PR is found: check whether it modifies files related to the issue area.
4. If no PR found: check commits mentioning `#N`.

### gh Commands

```bash
# Find closed issues in last 30 days
gh issue list --state closed --limit 100 \
  --json number,title,closedAt,stateReason \
  | jq '[.[] | select(.closedAt > (now - 2592000 | todate))]'

# Find PRs that close an issue
gh pr list --state merged --search "closes #$N" --json number,title,mergedAt

# Check which files a PR touched
gh pr view $PR_NUMBER --json files --jq '.files[].path'

# Reopen if no resolution found
gh issue reopen $N --comment "Reopening: no merged pull request or commit was found that resolves this issue. Please link the fixing PR or provide evidence of resolution."
gh issue edit $N --add-label "needs-verification"
```

---

## Check 4: Label and Type Enforcement

**Goal**: Ensure every issue has the minimum required labels.

### Minimum Required Labels

| Category | Required | Valid values |
|----------|----------|-------------|
| Type | 1 | `bug`, `enhancement`, `documentation`, `chore`, `security`, `question` |
| Priority | 1 | `priority:critical`, `priority:high`, `priority:medium`, `priority:low` |
| Sprint | 1 | `sprint:<number>` |
| Area | 0–1 | `area/*` labels defined in repo |

Legacy labels (`P0-critical`, `P1-high`, `P2-medium`, `P3-low`, `priority/critical`, `priority/high`, `priority/medium`, `priority/low`) are migration-only and should be normalized to canonical `priority:*` labels during triage runs.
Repo-specific delivery labels such as `area/*`, `sprint:*`, and legacy `sprint-*` labels must be preserved during cleanup; only governance labels should be normalized automatically.

### Inference Rules

| Signal in title/body | Inferred type |
|---------------------|---------------|
| "error", "crash", "fail", "broken", "regression" | `bug` |
| "add", "support", "allow", "feature", "request" | `enhancement` |
| "doc", "readme", "guide", "typo", "spelling" | `documentation` |
| "CVE", "vuln", "secret", "injection", "XSS" | `security` |
| "refactor", "cleanup", "debt", "upgrade" | `chore` |
| "how", "why", "what", "clarify", "explain" | `question` |

### gh Commands

```bash
# Check labels on an issue
gh issue view $N --json labels --jq '.labels[].name'

# Apply inferred labels
gh issue edit $N --add-label "bug,priority:high"

# Flag for manual triage
gh issue edit $N --add-label "needs-triage"
gh issue comment $N --body "This issue is missing required labels:\n- [ ] Type: bug / enhancement / documentation / chore / security / question\n- [ ] Priority: priority:critical / priority:high / priority:medium / priority:low\n- [ ] Sprint: sprint:<number> (for example, sprint:35)"
```

---

## Check 5: Title Quality

**Goal**: Ensure titles are descriptive and searchable.

### Quality Rules

| Rule | Pass | Fail |
|------|------|------|
| Length ≥10 chars | "Login fails on mobile Safari" | "bug" |
| Contains meaningful word | "Add dark mode support" | "issue with thing" |
| Not a generic stop phrase | "OAuth callback 500 error" | "fix", "help", "todo" |
| Not duplicate of existing title | Unique title | Same as #123 |

### Comment Template

```markdown
**Suggested title improvement**

The current title `{current_title}` is too generic to be useful in search or sprint planning.

Suggested: `{suggested_title}`

Please update the title if this better reflects the issue. The agent will not rename it automatically.
```

---

## Check 6: Proposed Fixes and Related Linkage

**Goal**: Surface related code, issues, and suggested resolutions.

### Comment Template

```markdown
## Related Files
<!-- Files likely related to this issue, found via keyword search -->
- `src/auth/callback.ts` — contains OAuth callback handler
- `src/middleware/token.ts` — token validation logic

## Related Issues
- #145 — OAuth token refresh fails after 1 hour (related)
- #201 — Add PKCE support for OAuth flow (parent)

## Related PRs
- #PR-198 — Partial fix for callback URL handling (merged)

## Proposed Resolution
Based on the error message `invalid_grant` in the body, this is likely caused by token expiry not being handled in `callback.ts`. A guard clause checking token age before exchange should resolve it.
```

---

## Check 7: Relationship Audit

**Goal**: Make implicit relationships explicit.

### Relationship Keywords

| Pattern found | Inferred relationship | Marker to add |
|--------------|----------------------|---------------|
| `#N` in body without keyword | `mentions` | `Mentions #N` |
| "blocked by #N" | `blocked-by` | Add `blocked` label; comment `Blocked by #N` |
| "depends on #N" | `depends-on` | Comment `Depends on #N` |
| "part of #N" | `child-of` | Comment `Part of #N` |
| "after #N" / "once #N" | `depends-on` | Comment `Depends on #N` |

### gh Commands

```bash
# Add blocked label
gh issue edit $N --add-label "blocked"
gh issue comment $N --body "Blocked by #$BLOCKER — cannot proceed until that issue is resolved."
```

---

## Check 8: Branch Connection

**Goal**: Link open branches and missing PRs to their issues.

### Search Pattern

```bash
# List all branches
gh api "repos/$OWNER/$REPO/branches" --paginate --jq '.[].name' \
  | grep -E "^(feat|fix|chore|copilot)/$N-"

# Check if a PR exists for a branch
gh pr list --head "$BRANCH_NAME" --json number,state
```

### Comment Template

````markdown
**Open branch found**

Branch `fix/245-oauth-callback` exists but no pull request is linked to this issue.

If work is in progress, consider opening a PR to track it:
```bash
gh pr create --head fix/245-oauth-callback --base main --title "fix: OAuth callback error" --body "Closes #245"
```
````

---

## Check 9: Priority Review

**Goal**: Calibrate priorities to actual risk and age.

### Auto-escalation Rules

| Condition | Action |
|-----------|--------|
| `security` label + no `priority:critical` | Add `priority:critical` |
| Open >90 days + no activity | Add `stale` |
| Open >30 days + `bug` + has repro steps | Add `priority:high` if no priority set |
| No priority label at all | Apply `priority:low` as floor |

### gh Commands

```bash
# Upgrade to critical
gh issue edit $N --add-label "priority:critical"
gh issue comment $N --body "Priority escalated to critical: security issues are automatically assigned critical priority per triage policy."

# Mark stale
gh issue edit $N --add-label "stale"
gh issue comment $N --body "This issue has been open for >90 days with no activity. Marking as stale. If still relevant, please add a comment to keep it active."
```
