---
name: agentic-sdlc-autonomy
description: "Use when asked to audit, measure, implement, or operate rules-based human-in-the-loop autonomy for agent-operated repositories. USE FOR: agentic SDLC governance, PR risk classification (A0-A5), auto-merge policy, merge queue gates, deployment lane policy, DB migration controls, IaC safety rules, runner isolation, production approval flows, and policy-versus-settings drift. DO NOT USE FOR: direct deployment, production DB migrations, infrastructure apply, secrets rotation, or branch/environment protection changes without explicit human authorization."
compatibility:
  - agent:agentic-sdlc-autonomy
  - skill:ci-audit
  - skill:flow-audit
  - skill:flow-admission-control
  - skill:human-in-the-loop
metadata:
  domain: sdlc-governance
  maturity: beta
  audience:
    - maintainer
    - platform-engineer
    - release-manager
allowed-tools:
  - bash
  - git
  - gh
  - python
visibility: public
---

# Agentic SDLC Autonomy Skill

Rules-based autonomy model: agents own throughput, CI owns verification, policy
owns classification, humans own irreversible risk.

## When to Use

- Auditing repo governance posture against A0-A5 autonomy levels
- Scoring SDLC maturity (branch protection, merge queue, DB/IaC gates, runner isolation)
- Classifying PR risk and routing to auto-merge or human-approval
- Designing deployment lane policies and WIP limits
- Detecting policy-versus-settings drift

## Autonomy Levels

| Level | Name | Meaning |
|---:|---|---|
| A0 | observe/report | agents audit and propose only |
| A1 | safe edits | docs, tests, lint, non-runtime refactors |
| A2 | feature work | bounded app/package changes with tests |
| A3 | auto-merge eligible | low-risk after required checks pass |
| A4 | non-prod eligible | preview/staging when policy allows |
| A5 | human-gated | prod cutover, prod DB migration, IaC apply, secrets, auth, branch/env protection |

## Risk Classification

| Risk | Autonomy | Typical scope |
|---|---|---|
| low | A1-A3 | docs, tests, lint, copy, small safe refactors |
| medium | A2-A4 | app/package changes, non-breaking config, non-prod deploys |
| high | A5 | CI workflows, DB migrations, IaC, auth, security, prod env |
| critical | plan-first + A5 | destructive DB/IaC, prod cutover, secrets rotation, governance bypass |

For risk path/keyword rules see `references/autonomy_policy.md`.
For PR risk classification script see `scripts/classify_pr_risk.py`.
For output templates see `references/report_templates.md`.

## Modes

1. **Audit** — repo posture from evidence; separate findings by source
2. **Measure** — 0-5 scorecard across 14 governance dimensions plus queue metrics
3. **Implement** — phased policy/workflow/script changes, report-only first
4. **Operate** — classify PR risk, output decision and recommended labels

## Output

- Audit: executive summary, drift table, risk register, roadmap phases
- Measure: scorecard, queue metrics, gap list
- Implement: phased plan, files to change, validation checklist, manual settings, rollback
- Operate: risk level, autonomy level, decision, labels, reasons

## Related Assets

- `agents/agentic-sdlc-autonomy.agent.md`
- `skill:ci-audit`
- `skill:flow-audit`
- `skill:flow-admission-control`
- `skill:human-in-the-loop`
