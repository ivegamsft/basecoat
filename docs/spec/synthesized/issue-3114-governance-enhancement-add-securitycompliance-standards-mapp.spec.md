---
issue: 3114
title: "Governance enhancement: add security/compliance standards-mapping layer (OWASP/NIST/AI-RMF/WAF/CAF)"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governance enhancement: add security/compliance standards-mapping layer (OWASP/NIST/AI-RMF/WAF/CAF)

## Problem Statement

**Gap (vs HVE):** HVE maps every component to OWASP/NIST/AI-RMF/WAF/CAF with explicit per-component gap analysis (`standards-mapping.instructions.md` + `security-planning` skill). basecoat references specific guardrails but has no formal standards crosswalk/gap-analysis artifact.

**Proposal:** Add an optional standards-mapping skill/instruction that crosswalks migration components to named standards and emits a coverage + gap report. Consider runtime lookup for volatile frameworks (WAF/CAF/PCI/FedRAMP).

**Existing partial coverage:** `security-operations`, `supply-chain-security`, `azure-policy-audit` skills.

Refs benchmark analysis. Parent: #3113

## Why This Matters

Standards references are currently scattered across instructions, skills, and
docs. A structured crosswalk turns those references into reviewable evidence and
helps downstream repositories decide which governance assets to adopt for their
own security and compliance posture.

## Scope

Implement an advisory standards-mapping layer. The first supported framework
set is OWASP, NIST, Microsoft Cloud Adoption Framework (CAF), Microsoft Azure
Well-Architected Framework (WAF), and NIST AI Risk Management Framework
(AI RMF). Additional frameworks can be added only through the taxonomy source.

1. Add a standards taxonomy file or equivalent data source that records
   supported framework categories, owner, freshness date, and permitted
   citation style.
2. Add a skill/instruction workflow that accepts a component, repository area,
   or migration plan and emits:
   - mapped BaseCoat assets,
   - coverage status (`covered`, `partial`, `gap`, `not-applicable`),
   - evidence paths,
   - caveats and next recommended review.
3. Avoid copying restricted standards text. Use framework names, section IDs,
   public citations, and BaseCoat-owned summaries only.
4. Add implementation-ready contracts:
   - input contract: component name, component type, repository paths, optional
     cloud/workload context, and requested framework set,
   - output contract: framework, category/control identifier, coverage status,
     mapped BaseCoat asset paths, evidence summary, caveat, and next action,
   - failure handling: unknown frameworks fail with an actionable message;
     stale taxonomy entries warn but do not invent mappings; missing evidence is
     reported as `gap`.
5. Add tests or fixture validation for at least one `covered`, `partial`, `gap`,
   and `not-applicable` result.

## Architecture

The implementation should separate static knowledge from report generation:

- `docs/reference/standards-mapping.*` or an equivalent checked-in taxonomy is
  the source of truth for supported frameworks, category IDs, freshness dates,
  and allowed citation mode.
- A standards-mapping skill or instruction consumes the taxonomy and repository
  evidence, then emits a report. The report generator must not hard-code
  framework text outside the taxonomy.
- Existing assets such as security, supply-chain, Azure policy, and WAF review
  skills remain the authoritative implementation evidence; the mapping layer
  points to them rather than duplicating their controls.

## Security and Compliance Boundaries

Mappings are **advisory** and are **not compliance attestations, certifications,
or legal advice**. Reports must include that disclaimer and must not reproduce
restricted standards text. If a requested standard cannot be cited under the
allowed citation style, the tool should use public identifiers and BaseCoat-owned
summaries or mark the mapping as unavailable.

## Testing and Rollout

Roll out behind documentation and fixture validation first. Add fixtures for:

- `covered`: a component mapped to an existing BaseCoat security asset,
- `partial`: a component with some matching governance evidence but missing a
  required supporting artifact,
- `gap`: a component with no mapped evidence,
- `not-applicable`: a framework/category that does not apply to the component
  type.

Validation should exercise the taxonomy parser, report schema, unknown-framework
failure path, stale-taxonomy warning path, and restricted-text guard.

## Observability

Generated reports should include the taxonomy version or freshness date, selected
frameworks, total mapped categories by status, and any warnings. This allows
downstream consumers to tell whether a report is current enough to use for
planning.

The design should prefer data-driven mappings over hard-coded prose so future
framework updates can refresh the taxonomy without rewriting the workflow.

## Acceptance Criteria

- [ ] Standards taxonomy or mapping source is checked in and referenced by the
  workflow.
- [ ] The initial taxonomy covers OWASP, NIST, Microsoft CAF, Microsoft WAF, and
  NIST AI RMF identifiers or categories at a level safe to cite.
- [ ] Generated reports include coverage status, evidence paths, and caveats.
- [ ] Generated reports state that mappings are advisory and not compliance
  attestations, certifications, or legal advice.
- [ ] Restricted standards text is not copied into BaseCoat artifacts.
- [ ] Tests or fixtures validate covered/partial/gap/not-applicable outcomes.
- [ ] Unknown frameworks and stale taxonomy data produce explicit diagnostics.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3114-governance-enhancement-add-securitycompliance-standards-mapp.prd.md`
- Refs #3114
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3114>
