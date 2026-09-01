# Backlog Revalidation Classification Contract

Shared vocabulary for issues and pull requests. Age and activity select
candidates; they never justify a disposition by themselves.

## Evidence contract

```text
Item: issue #<n> | pull #<n>
Mode: single | batch | scheduled
Age filter only: yes
Classification: still-needed | needs-modification | superseded | recurring | already-resolved | duplicate | not-needed | insufficient-evidence
Confidence: high | medium | low - <why>
Citations: <issue/PR/commit/file:line/release/ADR>
Canonical: <url or none>
Recommended action: comment | label | close | reopen | human-review | none
Mutation performed: none | <explicit requested action>
```

## Classes

| Class | Meaning | High-confidence action |
|---|---|---|
| still-needed | Problem and outcome remain current | Keep open; optional priority/label refresh |
| needs-modification | Need remains; scope, AC, or deps changed | Propose revised title/scope; do not silently rewrite |
| superseded | Newer issue, PR, release, ADR, or implementation replaces it | Close only with canonical link |
| recurring | Previously resolved behavior returned, or multiple episodes | Keep/open canonical tracker; link episodes |
| already-resolved | Current behavior or merged work satisfies the item | Close only with merged evidence or demonstrated behavior |
| duplicate | Same unresolved outcome is tracked elsewhere | Close only with `Duplicate of #N` |
| not-needed | Direction, architecture, policy, or platform makes it obsolete | Close with policy/version citation |
| insufficient-evidence | No safe disposition | Human-review queue |

## Decision policy

- Scheduled mode is always report-only (`Mutation performed: none`).
- Distinguish `recurring` from `duplicate`. Recurrence is not duplicate closure.
- A reverted merge, partial file change, or later product-direction reopen is
  not `already-resolved`.
- Textual similarity without shared outcome and evidence is
  `insufficient-evidence`.
