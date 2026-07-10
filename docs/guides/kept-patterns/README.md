# Kept Patterns Registry

This registry tracks patterns promoted to **Keep** status for workstream 1 in
issue [#2046](https://github.com/ivegamsft/basecoat/issues/2046).

## Promotion Criteria

A candidate pattern is promoted only when all criteria are met:

1. Proven in at least three independent runs or contexts.
2. Throughput or quality gains are measurable and repeatable.
3. No critical regressions in the observation window.
4. Runbook is documented with prerequisites, decision points, and rollback.

Use `docs/guides/keep-candidate-acceptance-checklist.md` to evaluate new
candidates before promotion.

## Promoted Defaults

| Pattern | Default owner | Primary signal | Runbook |
|---|---|---|---|
| Phase-boundary compaction | Operator | Lower token/event carry-over per phase | `phase-boundary-compaction.md` |
| File-reference-only context loading | Operator | Lower prompt payload size and less context reuse bloat | `file-reference-only-context.md` |
| Single kickoff plus `/tasks` monitoring | Operator | Fewer orchestration restarts and lower control-plane overhead | `single-kickoff-tasks-monitoring.md` |

## Adoption Target

The Keep/Fix/Throttle model target for promoted patterns is at least 80%
adoption across tracked runs. Track adherence in weekly operational summaries and
close drift with remediation issues when adoption drops below target.
