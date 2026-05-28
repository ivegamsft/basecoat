---
name: sprint-closeout-audit
description: "Use when auditing sprint closure readiness with explicit pass/fail evidence for merge state, CI health, unresolved errors, open issues, and test execution. USE FOR: run end-of-sprint completion checklist, validate carry-forward decisions, produce closeout report for leadership, and gate next-sprint planning until closure criteria are explicit. DO NOT USE FOR: feature implementation, architecture design, or standalone incident response."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Project Management"
  tags: ["sprint", "closeout", "audit", "agile", "checklist"]
  maturity: "beta"
  audience: ["engineering-managers", "tech-leads", "developers"]
allowed-tools: ["bash", "git", "gh", "grep"]
invocation_rules:
  - "Use when closing a sprint and validating objective completion evidence."
  - "Require all five checklist questions with evidence links in output."
visibility: "internal"
---

# Sprint Closeout Audit Skill

Use this skill to perform a checklist-driven sprint closeout audit before starting the next sprint.

## Checklist Protocol

Always answer these six questions:

1. ✅ Did everything merge?
2. ✅ Did CI pass?
3. ✅ Any errors?
4. ✅ Any issues?
5. ✅ Did you test?
6. ✅ Is latest-main CI green?

Each answer must include:

- status (`yes`, `partial`, or `no`)
- evidence pointer (issue/PR/workflow/test reference)
- carry-forward action when not fully green

## Latest-Main CI Gate

Question 6 is a hard gate. Before marking sprint closeout complete, verify:

- All required workflows on the latest `main` commit are green (no failures).
- No `action_required` approval blocks exist on latest `main` runs.
- Evidence links point to specific workflow run URLs, not just branch summaries.

If any required workflow is failing or blocked, the sprint is not closeable.
Record the failing workflow name, run URL, and a remediation action as a
carry-forward blocker.

### CI gate commands

```bash
# List recent main branch workflow runs
gh run list --branch main --limit 10

# Check for failures on main
gh run list --branch main --status failure --limit 5

# Check for approval blocks on main
gh run list --branch main --status action_required --limit 5
```

## Reference Files

| File | Purpose |
|---|---|
| [`references/checklist-template.md`](references/checklist-template.md) | Output template and evidence requirements |

## Agent Pairing

- `sprint-closeout-auditor`
- `sprint-planner`
- `retro-facilitator`
- `git-worktrees` for cleanup of parallel worktree-based sprint branches
