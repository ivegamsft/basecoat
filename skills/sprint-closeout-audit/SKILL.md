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

Always answer these five questions:

1. ✅ Did everything merge?
2. ✅ Did CI pass?
3. ✅ Any errors?
4. ✅ Any issues?
5. ✅ Did you test?

Each answer must include:

- status (`yes`, `partial`, or `no`)
- evidence pointer (issue/PR/workflow/test reference)
- carry-forward action when not fully green

## Reference Files

| File | Purpose |
|---|---|
| [`references/checklist-template.md`](references/checklist-template.md) | Output template and evidence requirements |

## Agent Pairing

- `sprint-closeout-auditor`
- `sprint-planner`
- `retro-facilitator`
- `git-worktrees` for cleanup of parallel worktree-based sprint branches
