---
name: issue-triage
compatibility: [github-copilot-cli]
description: "Audits GitHub issues for quality, validity, duplicates, labels, and priority. USE FOR: backlog hygiene and duplicate detection, validating closed issues have resolution evidence, enforcing label/type/priority conventions, auditing titles and relationships. DO NOT USE FOR: implementing product features, writing deployment pipelines, editing application runtime code, running non-triage project planning."
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
allowed-tools: []
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
| [`references/metadata-contract.md`](references/metadata-contract.md) | Minimum metadata required before `approved` and `copilot-agent` labels can be applied |

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

Canonical priorities are `priority:critical`, `priority:high`, `priority:medium`, and `priority:low`.

## Agent Pairing

- `issue-triage` agent for fully automated triage runs.
- `backlog-burndown` for sprint velocity and scope tracking.
- `sprint-planner` for placing triaged issues into sprint commitments.
- `escalation-router` for issues requiring human sign-off before action.
