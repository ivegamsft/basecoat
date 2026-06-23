# Issue Metadata Contract

This document defines the minimum metadata an issue must carry before it can receive the `approved` or `copilot-agent` label and be handed off to the Copilot coding agent.

All tooling — approval workflows, triage scripts, and audit jobs — must reference this single contract.

---

## Contract: `approved` label

An issue may receive the `approved` label **only if** ALL of the following are satisfied:

| Requirement | Rule |
|---|---|
| **Type label** | Exactly one of: `bug`, `enhancement`, `documentation`, `chore`, `security`, `question` |
| **Priority label** | Exactly one of: `priority:critical`, `priority:high`, `priority:medium`, `priority:low` |
| **Actionable body** | Issue body ≥50 characters of meaningful text |
| **Not a duplicate** | The `duplicate` label must not be present |
| **Not closed/invalid** | The `invalid` or `wontfix` label must not be present |

> **Sprint/grouping label:** Recommended but not enforced as a hard gate for `approved`. Issues without a sprint label will be surfaced by the hygiene audit for follow-up assignment.

---

## Contract: `copilot-agent` label

An issue may receive the `copilot-agent` label **only if** ALL of the following are satisfied:

| Requirement | Rule |
|---|---|
| **Satisfies `approved` contract** | All `approved` requirements above must pass |
| **Type is agent-actionable** | Must be one of: `bug`, `enhancement`, `chore`, `documentation` (not `question` — questions are not implementation tasks) |
| **Not blocked** | The `blocked` or `needs-info` label must not be present |

---

## Rejection behavior

When an issue fails the contract, the approval workflow must:

1. **Not apply** `approved` or `copilot-agent`.
2. **Add** `needs-triage` label to surface it for cleanup.
3. **Post a comment** listing the specific missing fields with the following template:

```markdown
⛔ **Approval blocked — incomplete metadata**

This issue cannot be approved until the following required metadata is complete:

<!-- list each missing field -->
- [ ] **Type label** — add one of: `bug`, `enhancement`, `documentation`, `chore`, `security`, `question`
- [ ] **Priority label** — add one of: `priority:critical`, `priority:high`, `priority:medium`, `priority:low`

Once all required labels are present, comment `/approve` again to retry.
```

---

## Hygiene audit

A scheduled hygiene audit (`issue-metadata-hygiene.yml`) runs weekly to surface issues that have already received `approved` or `copilot-agent` but no longer satisfy the contract. Violations are reported in the workflow summary for manual remediation.

---

## Relationship to triage tooling

- **`issue-triage` skill** — applies type and priority labels during triage. Issues that pass triage should already satisfy this contract.
- **`quality-checklist.md`** — defines the broader quality bar (title, body, encoding, etc.). This contract is a subset focused on approval gating.
- **`triage-workflow.md`** — Check 4 (Label/Type Enforcement) is the upstream step that prepares issues for this contract.

---

## Label reference

| Category | Valid values |
|---|---|
| Type | `bug`, `enhancement`, `documentation`, `chore`, `security`, `question` |
| Priority | `priority:critical`, `priority:high`, `priority:medium`, `priority:low` |
| Blocking state labels | `blocked`, `needs-info`, `duplicate`, `invalid`, `wontfix` |
