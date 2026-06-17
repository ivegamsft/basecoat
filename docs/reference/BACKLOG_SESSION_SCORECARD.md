# Backlog Session Scorecard

Generated from a repository-tracked measurement ledger so issue #1361 has
operational data instead of an advisory-only target.

- Generated: 2026-06-13 14:31:50 -0400
- Source data: `.github/backlog-session-metrics.json`
- Output: `docs/reference/BACKLOG_SESSION_SCORECARD.md`
- Refresh command: `python scripts/generate-backlog-efficiency-scorecard.py`
- Tracking window: latest 5 recorded backlog sessions
- Target band: 35,000,000-45,000,000 tokens
- Expensive baseline: 68,000,000-84,000,000 tokens
- Best measured reference: 9,100,000 tokens, 101 events, 207x ratio

## Scorecard Summary

No backlog sessions have been recorded yet.

| Metric | Value |
|---|---|
| Sessions recorded | 0 |
| Sessions remaining to fill window | 5 |
| Sessions in 35-45M target band | 0/0 |
| Average tokens | - |
| Average events | - |
| Average ratio | - |
| Average savings vs 76M midpoint | - |
| Average phase compactions | - |
| Average max prompt size | - |

## Policy Adoption

| Practice | Threshold | Adoption |
|---|---|---|
| Phase-boundary compaction | >= 2 compactions | 0/0 |
| Sprint template reuse | `usedSprintTemplate = true` | 0/0 |
| File-reference-only prompts | `usedFileReferencesOnly = true` | 0/0 |
| Delegated scan work | `delegatedScanWork = true` | 0/0 |
| Max prompt size budget | <= 10 KB | 0/0 |

## Session Ledger

No backlog sessions have been logged yet. Add entries to
`.github/backlog-session-metrics.json` after each long run and regenerate this report.

## Logging Contract

Record one object per backlog session with these required fields:

```json
{
  "date": "2026-06-13",
  "label": "Backlog sprint execution",
  "tokens": 41200000,
  "events": 188,
  "ratio": 233,
  "phaseCompactions": 2,
  "maxPromptKb": 6.4,
  "usedSprintTemplate": true,
  "usedFileReferencesOnly": true,
  "delegatedScanWork": true,
  "notes": "Compact at triage->implementation and implementation->merge-waiting."
}
```

Use this scorecard together with `docs/templates/sprint-structure.md` and
`.github/instructions/cost-optimization.instructions.md` to keep the next
5 backlog sessions inside the 35-45M token target band.
