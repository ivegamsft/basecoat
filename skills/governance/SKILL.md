---
name: governance
compatibility: [github-copilot-cli]
description: "Use when defining the shared governance layer, separating common from repo-specific rules, or revising canonical metadata. USE FOR: common-vs-specific policy docs, canonical label contracts, migration maps, template guidance, and governance issue planning. DO NOT USE FOR: application implementation, one-off issue cleanup, or release operations."
category: governance

metadata:
  category: governance
  domain: governance
  maturity: production
  audience:
    - maintainer
    - docs-author
allowed-tools:
  - bash
  - git
  - gh
visibility: public
---
# Governance Skill

Use this skill to write and maintain the canonical guidance that keeps shared
rules separate from repo-specific rules.

## When to Use

- Writing or revising `docs/reference/governance-contract.md`
- Defining a canonical label contract
- Separating common rules from repo-specific exceptions
- Creating a migration map for legacy labels
- Planning governance follow-up issues

## Workflow

1. Identify the shared rules that should apply everywhere.
2. Identify the repo-specific rules that should stay local.
3. Write the canonical contract first, then add exceptions.
4. Add a migration map for any legacy labels or fields.
5. Link the result to the relevant issue and PR templates.

## Output

- A clear guidance draft
- A canonical label and field contract
- A short list of unresolved gaps to file as issues

## Related Assets

- `agents/governance-author.agent.md`
- `agents/governance-auditor.agent.md`
- `docs/reference/governance-contract.md`
- `docs/reference/label-taxonomy.md`
- `docs/operations/label-cleanup-plan.md`
