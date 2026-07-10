# Sprint Closeout Checklist

## Latest-Main CI Gate

Before starting the closeout, confirm the repository is in a healthy state:

- Run `gh run list --branch main --limit 10` and confirm all required workflows are green.
- Run `gh run list --branch main --status failure --limit 5` to check for active failures.
- Run `gh run list --branch main --status action_required --limit 5` to check for approval blocks.

If any required workflow is failing or `action_required`, stop the closeout, record the
failing workflow run URL as a blocker, and resolve before proceeding.

## 1. Goal and Scope Closure

- Confirm sprint goals met / partially met / missed.
- Enumerate completed items with links.
- Enumerate spillover items and reasons.

## 2. Quality and Delivery Signals

- Defects opened vs resolved during sprint.
- Test pass/fail summary and notable quality risks.
- Deployment/release status for completed work.

## 3. Carry-Forward Planning

- For each incomplete item:
  - owner
  - blocker
  - next action
  - due date

## 4. Stakeholder Summary

Provide a compact closeout memo:

```text
Sprint Closeout — <Sprint Name>
- Goals met: ...
- Goals not met: ...
- Completed: <count>
- Carry-forward: <count>
- Highest risks into next sprint: ...

Committed actions:
1) <owner> - <action> - <date>
2) <owner> - <action> - <date>
```

## 5. Handoff to Next Sprint

- Confirm backlog reflects carry-forward priorities.
- Confirm retrospective agenda includes closeout learnings.
- Confirm release notes / stakeholder comms are published.
