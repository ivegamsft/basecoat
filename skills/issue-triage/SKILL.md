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

Use this skill to audit and improve GitHub issue quality. It can run standalone or as reference context for the `issue-triage` agent.

## Use Cases

- Backlog hygiene (invalid/duplicate/stale detection)
- Closed issue verification (confirm actual resolution evidence)
- Label and priority enforcement
- Duplicate/type-label exclusivity enforcement
- Title and relationship quality checks
- Branch linkage and missing-PR detection
- Proposed fix context for bug issues

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

## Triage Checks

1. Validity
2. Duplicate detection
3. Closed-issue verification
4. Label/type enforcement
5. Title quality
6. Proposed fixes + related links
7. Relationship audit
8. Branch connection
9. Priority review

## Agent Pairing

- `issue-triage` agent for fully automated triage runs.
- `backlog-burndown` for sprint velocity and scope tracking.
- `sprint-planner` for placing triaged issues into sprint commitments.
- `escalation-router` for issues requiring human sign-off before action.
