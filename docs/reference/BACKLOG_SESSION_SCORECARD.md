# Backlog Session Scorecard

Generated from a repository-tracked measurement ledger so issue #1361 has
operational data instead of an advisory-only target.

- Generated: 2026-10-09 02:53:31 -0400
- Source data: `.github/backlog-session-metrics.json`
- Output: `docs/reference/BACKLOG_SESSION_SCORECARD.md`
- Refresh command: `python scripts/generate-backlog-efficiency-scorecard.py`
- Tracking window: latest 5 recorded entries for practice metrics and ledger; latest 5 baseline-comparable sessions for target and savings
- Target band: 35,000,000-45,000,000 tokens
- Expensive baseline: 68,000,000-84,000,000 tokens
- Best measured reference: 9,100,000 tokens, 101 events, 207x ratio

## Scorecard Summary

Tracking in progress: 0/5 baseline-comparable session(s) recorded; 0/0 in the target band so far.

| Metric | Value |
|---|---|
| Recent ledger entries | 1 |
| Baseline-comparable sessions | 0 |
| Comparable sessions remaining to fill window | 5 |
| Baseline-comparable sessions in target band | 0/0 |
| Average tokens (baseline-comparable) | - |
| Average events | 326.0 |
| Average ratio | 113.9x |
| Average savings vs 76M midpoint (baseline-comparable) | - |
| Average phase compactions | 0.0 |
| Average max captured user-message size | 0.1 KB |

Baseline target-band and savings calculations use only sessions marked
`baselineComparable: true`. Other entries remain visible in the ledger but are
excluded from single-wave comparisons. Prompt-size values are captured user-message
measurements; check each entry's notes for coverage limitations.

## Policy Adoption

| Practice | Threshold | Adoption |
|---|---|---|
| Phase-boundary compaction | >= 2 compactions | 0/1 |
| Sprint template reuse | `usedSprintTemplate = true` | 0/1 |
| File-reference-only prompts | `usedFileReferencesOnly = true` | 0/1 |
| Delegated scan work | `delegatedScanWork = true` | 0/1 |
| Max captured user-message size | <= 10 KB | 1/1 |

## Session Ledger

| Date | Session | Tokens | Events | Ratio | Baseline Comparable | Compactions | Max Captured User Message | Template | File Refs | Delegated Scan | Notes |
|---|---|---:|---:|---:|---|---:|---:|---|---|---|---|
| 2026-10-09 | Oldest-first backlog wave (umbrella-session snapshot) | 44,184,376 | 326 | 113.9x | no | 0 | 0.1 KB | no | no | no | Refreshed snapshot at 2026-10-09T06:52:33Z UTC from the local session store; it spans multiple backlog waves and related issue/PR lanes, not one wave. This replaces the same umbrella's prior 2026-10-09T05:34:47.338Z cut (20,862,951 tokens, 153 API calls), rather than counting it as a second independent session. Cache-inclusive totals: 43,799,792 input + 384,584 output = 44,184,376 tokens; input already includes 42,320,200 cache-read and 1,477,676 cache-write tokens, not added again. The 326 events are recorded API calls, not GitHub workflow events; measured call duration was 4,474,052 ms. The local turn store captured 4 user messages (170 UTF-8 bytes total; maximum 94 bytes, 0.0918 KiB rounded to 0.1 KB); maxPromptKb reflects only those captured messages and excludes missing summarized history and system/tool payloads. No explicit phase-boundary compaction, sprint-template reuse, file-reference-only discipline, or delegated scan is evidenced across the captured umbrella; automatic history summarization is not counted as an explicit compaction. Raw event history and exact per-wave boundaries are unavailable. This is a measurement cut, not a final whole-session total; later closeout work is excluded. Do not infer per-wave savings or compare directly with a single-wave baseline. |

## Logging Contract

Record one object per backlog session with these required fields:

```json
{
  "date": "2026-06-13",
  "label": "Backlog sprint execution",
  "tokens": 41200000,
  "events": 188,
  "ratio": 233,
  "baselineComparable": true,
  "phaseCompactions": 2,
  "maxPromptKb": 6.4,
  "usedSprintTemplate": true,
  "usedFileReferencesOnly": true,
  "delegatedScanWork": true,
  "notes": "Compact at triage->implementation and implementation->merge-waiting."
}
```

Entries that omit `baselineComparable` are treated as comparable for
backward compatibility; mark umbrella or otherwise non-like-for-like runs
`false` so they remain visible without affecting baseline calculations.

Use this scorecard together with `docs/templates/sprint-structure.md` and
`.github/instructions/cost-optimization.instructions.md` to keep the next
5 backlog sessions inside the 35-45M token target band.
