---
name: standards-mapping
compatibility: [github-copilot-cli, copilot-coding-agent, copilot-chat]
description: "Use when crosswalking a repository area, migration plan, component, agent, or skill bundle to advisory security and governance standards. USE FOR: OWASP/NIST/CAF/WAF/AI RMF coverage mapping, standards gap reports, migration governance evidence review, and BaseCoat asset-to-framework crosswalks. DO NOT USE FOR: legal compliance attestation, copying restricted standards text, penetration testing, or replacing specialized security review."
category: governance
metadata:
  category: governance
  domain: security-compliance
  maturity: experimental
  audience:
    - maintainer
    - security-reviewer
    - solution-architect
visibility: public
allowed-tools: [bash, git, gh]
---
# Standards Mapping Skill

Produce advisory coverage and gap reports for a component, repository area,
migration plan, agent, or skill bundle.

## Contract

Load `docs/reference/governance/standards-mapping-taxonomy.json` and follow
`docs/reference/governance/standards-mapping.md`. Required input:
`componentName`, `componentType`, and `repositoryPaths`; optional input:
`frameworks` and `cloudWorkloadContext`.

Supported framework IDs are defined only in the taxonomy. Unknown framework
requests must fail with a diagnostic that lists supported IDs. Stale taxonomy
entry values warn and continue; report them as "Stale taxonomy entry" warnings.

## Report Rules

- Include the taxonomy advisory disclaimer and state reports are not compliance
  attestations, certifications, or legal advice.
- Use only public framework identifiers, category IDs, framework names, and
  BaseCoat-owned summaries. Do not copy restricted standards text.
- For each selected category, assign one status: `covered`, `partial`, `gap`,
  or `not-applicable`.
- Missing evidence is `gap`; do not invent mappings.
- Route follow-up work to specialized assets such as `api-security`,
  `supply-chain-security`, `azure-policy-audit`, `azure-waf-review`,
  `security-operations`, or `governance-audit`.

## Output

Return Markdown with taxonomy version, selected frameworks, status counts,
warnings, and a table: `Framework`, `Category`, `Status`, `Evidence paths`,
`Evidence summary`, `Caveat`, `Next action`.

Refs #3114.
