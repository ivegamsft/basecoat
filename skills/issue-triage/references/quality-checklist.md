# Issue Quality Checklist

Minimum-bar criteria, label taxonomy, type definitions, and priority matrix for the `issue-triage` agent.

---

## Minimum Bar — Required Fields

An issue passes the minimum bar if ALL of the following are true:

| Field | Rule |
|-------|------|
| **Title** | ≥10 chars; contains at least one meaningful word; not a stop-phrase |
| **Body** | ≥50 chars of meaningful text (not just a URL or template headers) |
| **Encoding integrity** | No mojibake/replacement-char corruption (e.g., `�`, `Ã`, `Â`, `â€™`, `â€œ`) |
| **Type label** | Exactly one from the type taxonomy |
| **Priority label** | Exactly one from the priority taxonomy |
| **For bugs** | Must include expected vs actual behavior, or error message/stack trace |
| **For enhancements** | Must include a problem statement or user story |

Issues that fail any required field receive `needs-triage` and a comment listing what is missing.
Encoding-integrity failures should be flagged with `needs-info` + `needs-triage` and a request to resubmit with UTF-8-safe text; they should not be auto-closed as invalid unless clearly spam.

---

## Label Taxonomy

### Type Labels (required — exactly one)

| Label | Use when |
|-------|----------|
| `bug` | Existing behavior differs from documented or expected behavior |
| `enhancement` | New capability, improvement to existing feature, or user experience improvement |
| `documentation` | Missing, incorrect, or out-of-date docs, README, or guides |
| `chore` | Non-user-facing maintenance: refactor, dependency upgrade, tooling |
| `security` | Vulnerability, secret exposure, injection risk, or CVE |
| `question` | Request for clarification, not a defect or feature |

### Priority Labels (required — exactly one)

| Label | Criteria | Response SLA |
|-------|----------|-------------|
| `P0-critical` | Service down, data loss, active security breach, CVE | Acknowledge within 1 hour |
| `P1-high` | Major feature broken, significant user impact, no workaround | Acknowledge within 4 hours |
| `P2-medium` | Minor feature issue, workaround exists, moderate user impact | Acknowledge within 1 business day |
| `P3-low` | Cosmetic, nice-to-have, documentation gaps, low user impact | Acknowledge within 1 week |

Legacy `priority/*` labels are still recognized by bulk triage scripts for backward compatibility.

### State Labels (applied by triage)

| Label | Meaning |
|-------|---------|
| `needs-triage` | Has not been reviewed; missing labels or information |
| `needs-info` | Waiting for additional information from the reporter |
| `needs-verification` | Closed without confirmed resolution; needs evidence |
| `duplicate` | Superseded by another issue (link in comment) |
| `invalid` | Not actionable: spam, gibberish, or outside scope |
| `blocked` | Cannot proceed until another issue or external action is resolved |
| `stale` | No activity for >90 days; may be closed if not updated |
| `wontfix` | Intentionally not resolved; out of scope or by design |

**Exclusivity rule:** `duplicate` cannot coexist with any type label (`bug`, `enhancement`, `documentation`, `chore`, `security`, `question`). If both are present, triage must resolve the conflict by keeping only one side.

### Area Labels (recommended — one or more)

Repos should define area labels matching their project structure. Common examples:

| Label | Applies to |
|-------|-----------|
| `area/extension` | Copilot extension / MCP layer |
| `area/portal` | Web portal frontend or backend |
| `area/infra` | Infrastructure, IaC, deployment |
| `area/docs` | Documentation |
| `area/ci` | GitHub Actions and CI/CD workflows |
| `area/auth` | Authentication and authorization |
| `area/api` | Public or internal API surface |

---

## Priority Matrix

Use this matrix to assign priority when it is not immediately obvious:

|   | High Impact | Low Impact |
|---|-------------|------------|
| **High Urgency** | `P0-critical` | `P1-high` |
| **Low Urgency** | `P2-medium` | `P3-low` |

**Escalation signals** (auto-upgrade):

- Title or body contains: `outage`, `data loss`, `security`, `CVE`, `incident`, `breach` → `P0-critical`
- Bug with no workaround and affecting primary user flow → `P1-high`
- Open >30 days with reproducible bug + no priority → `P1-high`
- Open >90 days with no activity → add `stale` regardless of priority

---

## Title Quality Rules

| Criterion | Pass example | Fail example |
|-----------|-------------|-------------|
| Length ≥10 characters | "OAuth callback returns 500" | "bug" |
| Contains meaningful noun or verb | "Add retry logic for token refresh" | "fix thing" |
| Not a stop-phrase | "Extension crashes on startup" | "help", "issue", "test", "todo" |
| Not a duplicate title | Unique | Same as existing open issue |
| Not ALL CAPS shouting | Mixed case normal prose | "BROKEN EVERYTHING FIX NOW" |

---

## Body Quality Rules

### Bug Issues Must Include

- [ ] Steps to reproduce (numbered list)
- [ ] Expected behavior
- [ ] Actual behavior (including error messages or screenshots)
- [ ] Environment (OS, browser, version, etc.)

### Enhancement Issues Must Include

- [ ] Problem statement: "As a [user], I need [capability] because [reason]"
- [ ] Acceptance criteria (what done looks like)

### Documentation Issues Must Include

- [ ] Link to the page or file that is wrong/missing
- [ ] Description of what is missing or incorrect

### Security Issues Must Include

- [ ] Impact description (what can an attacker do?)
- [ ] Steps to reproduce (if safe to share publicly; otherwise mark as private)
- [ ] Affected versions or components

---

## Duplicate Detection Thresholds

| Token overlap | Action |
|--------------|--------|
| >80% | Auto-close as duplicate; link canonical |
| 50–80% | Comment potential duplicate; flag for human review |
| <50% | No action; not a duplicate |

Token overlap calculation: strip stop words, lowercase, compute Jaccard similarity on word tokens.

---

## Relationship Markers

When adding relationship comments, use these standard phrases:

| Relationship | Standard comment phrase |
|-------------|------------------------|
| Duplicate | `Duplicate of #N — closing in favor of the original tracker.` |
| Blocked by | `Blocked by #N — cannot proceed until that issue is resolved.` |
| Depends on | `Depends on #N — this work should start after #N is complete.` |
| Part of | `Part of #N — this is a subtask of the parent issue.` |
| Related | `Related to #N — shares context or affected area.` |
| Mentions | `Mentions #N — for additional context.` |

---

## Stale Issue Policy

| Age | Status | Action |
|-----|--------|--------|
| >90 days, no comments | Stale | Add `stale` label; comment asking for status |
| >120 days, no response to stale comment | Inactive | Close with `wontfix`; comment inviting reopen |
| Exception: `P0-critical` or `P1-high` | Active regardless of age | Do not mark stale |
| Exception: `blocked` | Waiting state | Do not mark stale unless blocker is resolved |
