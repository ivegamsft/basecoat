# Backlog Session Scorecard

Generated from a repository-tracked measurement ledger so issue #1361 has
operational data instead of an advisory-only target.

- Generated: 2026-10-09 11:03:49 -0400
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
| Average events | 481.0 |
| Average ratio | 130.6x |
| Average savings vs 76M midpoint (baseline-comparable) | - |
| Average phase compactions | 0.0 |
| Average max captured user-message size | 0.2 KB |

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
| 2026-10-09 | Oldest-first backlog wave (umbrella-session snapshot) | 62,907,078 | 481 | 130.6x | no | 0 | 0.2 KB | no | no | no | Refreshed snapshot at usage_cut 2026-10-09T15:00:37.363Z UTC from the local session store; it spans multiple backlog waves and related issue/PR lanes, not one wave. This replaces the same umbrella's prior 2026-10-09T06:52:33Z cut (44,184,376 tokens, 326 recorded API calls), which replaced the older 2026-10-09T05:34:47.338Z cut (20,862,951 tokens, 153 recorded API calls); these are prior cuts of one umbrella, not independent sessions. Current cache-inclusive arithmetic is 62,429,108 input + 477,970 output = 62,907,078 total tokens; input already includes cache usage and cache counts are not added again. The input/output ratio is 130.6. The 481 events are recorded API calls, not GitHub workflow events. A separate captured-user-message query found 16 messages totaling 1,395 UTF-8 bytes; maximum message size was 209 bytes (about 0.2 KiB rounded). These are captured-only measurements from incomplete local history, not all prompts or total payload; the latest feature message is absent from captured turn data. Cache details and measured duration were not refreshed and are not reported as current. No new phase-compaction, sprint-template, file-reference-only, or delegated-scan benefit is claimed for this umbrella; the fresh context was used only for this accounting closeout, and automatic summaries are not /compact evidence. Raw event history and exact per-wave boundaries remain unavailable. This is a snapshot, not a final whole-session total; later closeout work is excluded. baselineComparable remains false: do not infer per-wave savings or compare directly with a single-wave baseline. |

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
