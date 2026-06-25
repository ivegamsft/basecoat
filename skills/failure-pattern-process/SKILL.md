---
name: failure-pattern-process
compatibility: [github-copilot-cli]
description: "Use when running the failure-pattern consumer process from mining through enhancement planning. USE FOR: evidence mining, append-only raw finding capture, common-versus-local triage with rationale, and prioritized enhancement planning with early-detection gates. DO NOT USE FOR: implementing repository feature changes, incident hotfix execution, or unsupported analysis without evidence links."

invocation_rules:
  - "Use when the task requires mining failure evidence and producing the full A1-D2 artifact chain."
visibility: "internal"
category: operations
---
# Failure Pattern Process Skill

Use this skill to execute a reusable, evidence-first failure-pattern process:

1. Mine failure patterns
2. Log raw findings without pruning
3. Triage common versus repo-specific patterns
4. Build a prioritized enhancement plan with early-detection gates

## Process Contract Alignment

This skill is aligned to:

- [`docs/operations/FAILURE_PATTERN_CONSUMER_PROCESS.md`](../../docs/operations/FAILURE_PATTERN_CONSUMER_PROCESS.md)
- [`docs/operations/FAILURE_PATTERN_RUN_CONTRACT.md`](../../docs/operations/FAILURE_PATTERN_RUN_CONTRACT.md)

Canonical stage model:

`queued -> mining -> raw_logged -> triaged -> planned -> completed`

Failure transition:

`* -> blocked`

## Artifact Pack

Required outputs:

- `A1-source-index`
- `A2-pattern-candidates`
- `B1-raw-findings-log` (append-only, no pruning)
- `C1-triage-matrix`
- `C2-classification-rationale`
- `D1-enhancement-backlog`
- `D2-early-detection-gates`
- `run-summary`

## Practical Templates

| Template | Purpose |
|---|---|
| [`templates/source-index-template.md`](templates/source-index-template.md) | Capture evidence sources with provenance and timestamps |
| [`templates/raw-findings-log-template.md`](templates/raw-findings-log-template.md) | Append-only raw findings record (duplicates retained) |
| [`templates/triage-matrix-template.md`](templates/triage-matrix-template.md) | Classify findings as common, repo-specific, or unknown with rationale |
| [`templates/enhancement-backlog-template.md`](templates/enhancement-backlog-template.md) | Prioritized enhancement items with validation methods |
| [`templates/early-detection-gates-template.md`](templates/early-detection-gates-template.md) | Define detection triggers, owners, and actions |
| [`templates/run-summary-template.md`](templates/run-summary-template.md) | Summarize stage transitions, gate outcomes, and handoff |

## Checklists

| Checklist | Purpose |
|---|---|
| [`checklists/gate-validation-checklist.md`](checklists/gate-validation-checklist.md) | Verify Gate 1 through Gate 4 completion criteria |

## Agent Pairing

- `failure-pattern-process`
- `rca`
- `incident-responder`


