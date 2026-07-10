---
description: "Sprint closeout guidance for label timing, triage, carryover tracking, and planning handoff"
applyTo: "skills/sprint-closeout/**/*,agents/basecoat-50-security-sprint-closeout-auditor.agent.md,.github/workflows/sprint-closeout-branch-audit.yml"
---

# Sprint Closeout Auditor

Use this guide when running sprint closeout so operational follow-up is captured
as structured work, not buried in prose.

## 1. Label Enforcement During Sprint

Apply sprint labels during active delivery, not at closeout.

- During PR review, verify sprint and wave labels are present before approval.
- Enforce `sprint:*` and `wave:*` labels on linked issues and pull requests.
- Treat missing labels as a workflow defect to fix immediately.
- Do not backfill labels at release-cut unless correcting a verified exception.

## 2. Error and Failure Triage

Classify closeout findings by severity and escalate consistently.

- **Critical**: production risk, blocked deploy, or data/security impact.
- **High**: repeat CI failures, merge blockers, or unresolved sprint blockers.
- **Medium/Low**: hygiene gaps, documentation updates, or non-blocking drift.

Escalation rules:

1. Critical and High findings must become explicit GitHub issues before closeout ends.
2. Each escalated issue needs an owner, due date, and evidence link.
3. Keep low-severity items in the closeout notes only if they are informational.

## 3. Two-Phase Checklist

Keep sprint closeout and release readiness as separate decisions.

### Phase A - Sprint Closeout

1. Scope complete and merged status confirmed
2. CI status verified on target branch
3. Error and blocker triage completed
4. Carryover captured as issues (when applicable)

### Phase B - Release Readiness

1. Release candidate branch/tag readiness verified
2. Environment-specific checks complete
3. Promotion blockers tracked separately from sprint carryover

Never mark sprint closeout complete based on release-only signals.

## 4. Carryover Management

Carryover items must be tracked as issues, not free-text action lines.

For each carryover:

1. Create a GitHub issue with clear problem statement and acceptance criteria.
2. Link the carryover issue to the closeout summary.
3. Set labels (`carryover`, sprint label, priority) and assignee.
4. Record source context (issue/PR/run URL) in the issue body.

Target outcome: zero untracked "Action (if needed)" prose items.

## 5. Handoff to Sprint Planning

Produce a structured handoff artifact for sprint-planner consumption.

Required handoff sections:

1. Sprint metrics (completed, carryover count, defect count)
2. Carryover issues list (issue number, owner, priority, due date)
3. New escalations from closeout triage
4. Recommended sprint planning priorities and sequencing constraints

The handoff must reference issue numbers directly so planning can ingest it
without re-triage.
