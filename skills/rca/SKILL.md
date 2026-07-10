---
name: rca
compatibility: [github-copilot-cli, copilot-chat, copilot-coding-agent]
description: "Root cause analysis for incidents, failures, and unexpected behavior. USE FOR: post-incident RCA, workflow/build failure analysis, 5-why investigation, tracing production outages to contributing factors, generating prevention recommendations. DO NOT USE FOR: live incident command and containment, general performance tuning, feature implementation."

invocation_rules:
  - "Use when the user prefixes input with 'rca:' or asks to investigate why something failed."
  - "Use for structured post-incident analysis after the system is stabilized."
visibility: "internal"
category: operations
metadata:
  category: operations
  maturity: stable
  audience:
    - developer
    - sre
allowed-tools: []
---
# RCA Skill

Structured root cause analysis workflow for incidents, pipeline failures, and unexpected behavior.

## Workflow

1. **Symptom triage** — clarify blast radius, customer impact, and observable symptoms.
2. **Timeline reconstruction** — map events leading up to the failure and identify inflection points.
3. **Theory generation** — propose at least three plausible root-cause hypotheses, ranked by likelihood.
4. **Evidence gathering** — list what confirms or refutes each theory; call out missing evidence.
5. **Root cause determination** — converge on the most likely cause with supporting evidence.
6. **Fix proposals** — suggest immediate mitigations and longer-term preventive fixes.
7. **Learnings capture** — identify updates for runbooks, guardrails, automation, and follow-up issues.

## Output Format

```markdown
## Incident Summary

## Timeline

## Root Cause Theories

## Determined Root Cause

## Proposed Fixes

## Learnings & Action Items
```

## Agent Pairing

- `rca` (basecoat-10-core-rca)
- `build-failure-triage`
- `ci-cd-diagnostics`
