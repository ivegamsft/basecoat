# Keep Candidate Acceptance Checklist

Use this checklist before promoting any new pattern to **Keep** status.

## Qualification Gates

| Gate | Pass criteria | Evidence |
|---|---|---|
| Reuse breadth | Demonstrated in at least 3 independent contexts or runs | Linked run logs, PRs, or issue evidence |
| Throughput or quality gain | Measurable improvement sustained across the observation window | Baseline vs post-change metrics |
| Safety | No critical failures attributable to the candidate pattern | Incident and issue review |
| Documentation readiness | Runbook includes prerequisites, decision points, and rollback | Published runbook path |
| Operability | Adoption signal is measurable and reportable weekly | Defined KPI and owner |

## Promotion Decision

A candidate is promoted only when every gate passes.

1. Add the runbook under `docs/guides/kept-patterns/`.
2. Register the pattern in `docs/guides/kept-patterns/README.md`.
3. Update default guidance in applicable `.github/instructions/*.instructions.md`
   files.
4. Add tracking notes to the linked workstream issue.

## Drift and Demotion Rules

- If adoption falls below 80% for two consecutive reporting windows, open a
  remediation issue.
- If the pattern causes a critical regression, demote it from defaults and add a
  rollback note in the runbook registry.
