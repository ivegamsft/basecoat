---
name: issue-triage
description: "Use when auditing GitHub issues for quality, validity, duplicate detection, label compliance, title integrity, relationship mapping, branch linkage, and priority enforcement. Provides structured checklists, triage workflows, and automation scripts."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Project Management & Planning"
  tags: ["issue-triage", "github", "quality", "duplicates", "labels", "priority", "backlog", "validation"]
  maturity: "production"
  audience: ["developers", "tech-leads", "engineering-managers", "contributors"]
allowed-tools: ["bash", "git", "gh"]
---

# Issue Triage Skill

Use this skill when you need a structured, repeatable process for auditing and improving GitHub issue quality. Works standalone or as a reference for the `issue-triage` agent.

## Use Cases

- **Backlog hygiene**: Catch gibberish, stale, and duplicate issues before sprint planning.
- **Closed issue audit**: Verify that closed issues were actually resolved with evidence.
- **Label enforcement**: Ensure every issue has a valid type, priority, and area label.
- **Title quality**: Detect meaningless titles and suggest improved ones.
- **Relationship mapping**: Link related issues, blocking issues, and parent/child hierarchies.
- **Branch connection**: Find orphaned branches and missing PRs for in-flight issues.
- **Proposed fixes**: Surface related code files and suggest resolution approaches for bugs.
- **Priority calibration**: Escalate under-prioritized security issues; mark stale long-lived issues.

## Reference Files

| File | Purpose |
|---|---|
| [`references/triage-workflow.md`](references/triage-workflow.md) | Step-by-step triage workflow with decision trees for each check |
| [`references/quality-checklist.md`](references/quality-checklist.md) | Minimum-bar criteria, label taxonomy, type definitions, and priority matrix |

## Scripts

| Script | Purpose |
|---|---|
| [`scripts/triage-issues.ps1`](scripts/triage-issues.ps1) | PowerShell automation for bulk triage using `gh` CLI (Windows/macOS/Linux) |
| [`scripts/triage-issues.sh`](scripts/triage-issues.sh) | Bash equivalent for Linux/macOS consumers |

## Quick Reference — Triage Checks

| Check | What it catches | Action |
|-------|----------------|--------|
| **Validity** | Gibberish, spam, unactionable issues | Close with `invalid`; reopen valid closed issues |
| **Duplicate** | Title/keyword overlap >80% | Link canonical, add `duplicate`, close newer |
| **Closed verification** | Closed without merged PR or code change | Reopen with `needs-verification` |
| **Label/type** | Missing type, priority, or area labels | Apply or flag with `needs-triage` |
| **Title quality** | Short, generic, or meaningless titles | Suggest improved title in comment |
| **Proposed fixes** | No related files or resolution noted | Comment with `## Related Files` and `## Proposed Resolution` |
| **Relationships** | Missing blocks/depends-on linkage | Add inferred relationship markers |
| **Branch connection** | Open branch without linked PR | Comment with branch name and suggest PR |
| **Priority review** | Security issues without critical; stale issues | Escalate or add `stale` |

## Agent Pairing

- `issue-triage` agent for fully automated triage runs.
- `backlog-burndown` for sprint velocity and scope tracking.
- `sprint-planner` for placing triaged issues into sprint commitments.
- `escalation-router` for issues requiring human sign-off before action.
