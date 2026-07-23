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

## Structured Build-Failure Intake

When the request is build/pipeline failure RCA, collect these required fields
before diagnosis:

1. Failing run URL
2. First failed job and step
3. First error block (minimal snippet)
4. Classification (`dependency`, `toolchain`, `test`, `env`, `config`)
5. Minimal rerun scope (targeted stage first, then full pipeline)

If required fields are missing, return an intake checklist and ask for only the
missing fields.

Known-signature handling:

1. Check for a known signature match using repository error KB patterns.
2. If matched, include prior fix references and confidence.
3. If unmatched, classify as novel and record pattern-candidate metadata for follow-up.

## Output Format

```markdown
## Incident Summary

## Timeline

## Root Cause Theories

## Determined Root Cause

## Proposed Fixes

## Learnings & Action Items
```

Build-failure RCA output must also include:

```markdown
## Intake Snapshot
- Run URL:
- First failed job/step:
- First error block:
- Classification:

## Rerun Plan
1. Targeted rerun:
2. Full pipeline rerun:

## Signature Match
- Matched signature: <id|none>
- Prior fix reference:
```

## Agent Pairing

- `rca` (basecoat-10-core-rca)
- `build-failure-triage`
- `ci-cd-diagnostics`
