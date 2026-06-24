# AIDL Learning-to-Memory Promotion Pipeline

This guide implements the learning-to-memory pipeline contract for AIDL portfolio operations.

## Purpose

The pipeline converts retrospective, incident, and review artifacts into governed memory-promotion packets with:

1. Candidate extraction and quality validation
2. Recurrence/impact scoring
3. Sensitive-content safeguards
4. Review-ready promotion payloads
5. Adoption-impact tracking after promotion

## Script

`scripts/aidl-learning-memory-promotion.ps1`

## Input Contract

Input is a JSON array where each candidate contains:

- `id`
- `sourceType` (`sprint`, `incident`, `review`, `governance`)
- `category` (for routing target)
- `title`
- `pattern`
- `resolution`
- `outcome`
- `evidence` (array of links)
- `recurrence` (integer)
- `impact` (1-5)
- `affectedTeams` (optional, integer)

## Execution

```powershell
pwsh -File scripts/aidl-learning-memory-promotion.ps1 `
  -InputPath artifacts/aidl-learning/input-candidates.json `
  -OutputDir artifacts/aidl-learning-memory-pipeline `
  -MinimumRecurrence 2 `
  -MinimumImpact 3 `
  -PromoteScoreThreshold 70 `
  -HoldScoreThreshold 45
```

## Output Artifacts

The pipeline emits:

- `candidate-summary.json` (all candidate decisions)
- `promotion-packets.json` (reviewable promote/hold payloads)
- `promotion-audit-ledger.json` (decision trail with rationale)
- `adoption-impact-tracking.json` (30-day tracking plan for promoted items)
- `promotion-report.md` (operator-facing summary and approval workflow)

## Decision Behavior

1. **Reject** when candidate is low-signal noise, missing required evidence, malformed, or includes sensitive content.
2. **Hold** when signal is moderate and requires manual approval.
3. **Promote** when recurrence/impact scoring exceeds promotion threshold and safeguards pass.

## Approval and Routing

`promotion-packets.json` includes routing metadata for downstream workflows:

- `decision-log-capture` for policy decisions
- `failure-pattern-process` for incident/runbook patterns
- `memory-promoter` for reusable guidance artifacts

Final approval is recorded in `promotion-audit-ledger.json` by the memory curator.
