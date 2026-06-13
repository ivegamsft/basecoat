---
name: governance-audit
description: "Use when auditing repo metadata, label drift, template gaps, and workflow enforcement coverage. USE FOR: issue and PR metadata audits, canonical-label drift checks, missing governance doc detection, and follow-up issue planning. DO NOT USE FOR: writing app code, changing labels without evidence, or release coordination."
compatibility:
  - agent:governance-auditor
  - agent:governance-author
metadata:
  domain: governance
  maturity: production
  audience:
    - maintainer
    - triager
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---

# Governance Audit Skill

Use this skill to audit the repo against the canonical governance contract.

## When to Use

- Checking issue and PR labels against the canonical taxonomy
- Looking for missing or stale governance docs
- Auditing issue and PR templates for stale references
- Reviewing workflows that should enforce metadata rules
- Preparing follow-up issues for uncovered gaps

## Workflow

1. Compare the live repo state to the canonical governance guide.
2. Identify missing docs, stale labels, and template drift.
3. Separate true gaps from repo-specific exceptions.
4. Summarize findings with severity and evidence.
5. File or propose GitHub issues for the unresolved gaps.

## Output

- Findings table
- Gap list
- Recommended follow-up issues

## Related Assets

- `agents/governance-auditor.agent.md`
- `docs/reference/governance-contract.md`
- `docs/reference/label-taxonomy.md`
- `docs/operations/label-cleanup-plan.md`
- `skills/issue-triage/SKILL.md`
