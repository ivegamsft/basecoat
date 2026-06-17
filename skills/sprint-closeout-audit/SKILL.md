---
name: sprint-closeout-audit
description: "Use when auditing sprint closure readiness with explicit pass/fail evidence for merge state, CI health, unresolved errors, open issues, and test execution. USE FOR: run end-of-sprint completion checklist, validate carry-forward decisions, produce closeout report for leadership, and gate next-sprint planning until closure criteria are explicit. DO NOT USE FOR: feature implementation, architecture design, or standalone incident response."
compatibility:
  - GHCP
invocation_rules:
  - "Use when closing a sprint and validating objective completion evidence."
  - "Require all five checklist questions with evidence links in output."
visibility: "internal"
category: operations
---
# Sprint Closeout Audit Skill

Checklist-based sprint closeout audit before next sprint planning.

## Checklist Protocol

Always answer these seven questions:

1. ✅ Did everything merge?
2. ✅ Did CI pass?
3. ✅ Any errors?
4. ✅ Any issues?
5. ✅ Did you test?
6. ✅ Is latest-main CI green?
7. ✅ Are merged sprint PRs labeled for release reporting (`sprint:*` or `wave:*`)?

Each answer must include status (`yes|partial|no`), evidence link, and carry-forward action when not green.

## Latest-Main CI Gate

Question 6 is a hard gate. Before marking sprint closeout complete, verify:

- All required workflows on the latest `main` commit are green (no failures).
- No `action_required` approval blocks exist on latest `main` runs.
- Evidence points to specific workflow run URLs.

If any required workflow is failing or blocked, the sprint is not closeable.
Record failing workflow, run URL, and remediation as carry-forward blocker.

## Label Coverage Gate

Question 7 is required when sprint output feeds release notes. If merged PRs are missing both `sprint:*` and `wave:*`, mark `partial`/`no` and add carry-forward action to backfill labels.

### CI gate commands

```bash
# List recent main branch workflow runs
gh run list --branch main --limit 10

# Check for failures on main
gh run list --branch main --status failure --limit 5

# Check for approval blocks on main
gh run list --branch main --status action_required --limit 5
```

## Reference

- [`references/checklist-template.md`](references/checklist-template.md)
