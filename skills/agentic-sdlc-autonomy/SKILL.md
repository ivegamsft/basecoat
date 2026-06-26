---
name: agentic-sdlc-autonomy
compatibility: [github-copilot-cli]
description: "Use when asked to audit, measure, implement, or operate rules-based human-in-the-loop autonomy for agent-operated repositories. USE FOR: SDLC governance, PR risk classification (A0-A5), merge/queue/deploy policy checks, and policy-versus-settings drift. DO NOT USE FOR: direct deployment, production DB migrations, infrastructure apply, secrets rotation, or branch/environment protection changes without explicit human authorization."
category: sdlc-governance

metadata:
  category: sdlc-governance
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

Rules-based autonomy model: agents execute throughput, CI verifies, policy
classifies risk, and humans approve irreversible changes.

## When to Use

- Auditing repo governance posture against A0-A5 autonomy levels
- Scoring maturity for branch protection, merge queue, deployment lanes, DB/IaC
  controls, and runner isolation
- Classifying PR risk and routing to auto-merge or human approval
- Detecting policy-versus-settings drift

## Autonomy and Risk Model

| Band | Meaning | Typical path |
|---|---|---|
| A0-A1 | Observe and safe edits | docs/tests/lint and non-runtime refactors |
| A2-A3 | Bounded change and auto-merge eligible | app/package changes with required checks |
| A4 | Non-prod execution eligible | preview/staging actions when policy allows |
| A5 | Human-gated only | prod cutover, prod DB migration, IaC apply, secrets/auth/protection changes |

Risk mapping: **low** (A1-A3), **medium** (A2-A4), **high** (A5), and
**critical** (plan-first plus A5).

For risk path/keyword rules see `references/autonomy_policy.md`.
For PR risk classification script see `scripts/classify_pr_risk.py`.
For output templates see `references/report_templates.md`.

## Modes and Output

1. **Audit** — evidence-based posture review. Output: summary, drift table, risk register.
2. **Measure** — 0-5 governance scorecard with queue metrics. Output: score and gap list.
3. **Implement** — phased policy/workflow/script changes, report-only first. Output: plan and rollback path.
4. **Operate** — PR risk classification and routing. Output: risk level, autonomy level, decision, and labels.

## Related Assets

- `agents/agentic-sdlc-autonomy.agent.md`
- `skill:ci-audit`
- `skill:flow-audit`
- `skill:flow-admission-control`
- `skill:human-in-the-loop`
