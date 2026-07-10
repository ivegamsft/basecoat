# Automation Stuck-State Watchdog

The `automation-stuck-state-watchdog.yml` workflow detects delivery stalls and opens remediation issues without waiting for manual triage.

## Stages and default SLAs

1. `issue_to_pr` (approved issue -> execution progress): 24 hours
2. `ready_to_merge` (merge-ready PR -> merged): 12 hours
3. `merge_to_release` (merged PR -> release-chain evidence): 2 hours

Defaults are defined in `.github/governance/automation-stage-slas.json` and can be overridden by `workflow_dispatch` inputs.

## Escalation record contract

Each watchdog escalation issue/comment includes:

- stage and entity (`issue` or `pr`)
- owner (`@login` when available)
- evidence link
- deterministic next action

Escalation issues are labeled `remediation`, `escalated`, and `automation`.

## False-positive suppression

Use one of these labels on an issue or PR to suppress watchdog escalation:

- `watchdog:ignore`
- `sla:exempt`
