# Kept Pattern Runbook: Phase-Boundary Compaction

## Intent

Prevent context bloat by compacting at semantic phase transitions instead of
waiting for token-pressure emergencies.

## Prerequisites

- Current objective and phase are explicit (triage, implementation, merge
  waiting).
- Canonical references are recorded (issue URL, PR URL, artifact paths).
- Open blockers are written as explicit action items before compacting.

## Default Procedure

1. At `triage -> implementation`, run `/compact`.
2. At `implementation -> merge waiting`, run `/compact`.
3. At any domain pivot where prior context is mostly irrelevant, run `/new`.
4. Reload only canonical references needed for the next phase.

## Decision Points

| Condition | Action |
|---|---|
| Same objective, phase switch only | `/compact` |
| Objective or domain changes | `/new` |
| Session still expensive after one compact | `/new` with minimal references |

## Rollback

If critical context was dropped, recover by reopening the canonical artifacts and
rebuilding only the required state for the current phase. Do not rehydrate full
historical transcripts.

## Evidence to Capture

- Event count before and after compaction.
- Token/input-output ratio trend across phases.
- Whether the run stayed below expensive-session thresholds.
