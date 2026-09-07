---
issue: 3115
title: "Governance enhancement: add IP/licensing posture (paraphrase-first, THIRD-PARTY-NOTICES, cite-only restricted standards)"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# Spec: Governance enhancement: add IP/licensing posture (paraphrase-first, THIRD-PARTY-NOTICES, cite-only restricted standards)

## Problem Statement

**Gap (vs HVE):** HVE ships a first-class `licensing-posture.instructions.md` (source classes, paraphrase-first default, THIRD-PARTY-NOTICES requirement, cite-only for ISO/IEC/ETSI) enforced as gating review findings. basecoat has no equivalent IP/attribution layer for vendored/quoted reference text.

**Proposal:** Add a licensing-posture instruction + reviewer check governing reproduction/attribution of upstream standards text in skills and docs.

**Existing partial coverage:** none first-class.

Parent: #3113

## Why This Matters

Licensing and attribution mistakes are hard to unwind after content ships
downstream. BaseCoat needs one reusable policy for external text so agents,
skills, docs, and generated PRD/spec artifacts can safely reference standards
and vendor guidance without copying content that BaseCoat cannot redistribute.

## Scope

Implement an IP and licensing posture layer for repository-authored and
generated content.

1. Add a licensing-posture instruction that covers:
   - docs and guides,
   - agent and skill prompts,
   - eval fixtures,
   - generated PRD/spec artifacts,
   - vendored examples or snippets.
2. Define source classes:
   - `basecoat-owned`: authored in this repository and safe to reuse under the
     repository license,
   - `public-reference`: source names, URLs, section IDs, and short factual
     identifiers,
   - `open-source-compatible`: copied only when license terms permit reuse and
     attribution is recorded,
   - `vendor-guidance`: summarized in BaseCoat-owned language unless license
     allows copying,
   - `restricted-standard`: cite-only for ISO, IEC, ETSI, paywalled, or
     license-controlled standards text,
   - `unknown`: block copying until the source class is determined.
3. Require paraphrase-first handling for `public-reference` and
   `vendor-guidance` sources. Direct quotations should be short, necessary, and
   attributed.
4. Require cite-only handling for `restricted-standard` sources. Use public
   identifiers, section numbers when safe, source names, and BaseCoat-owned
   summaries rather than reproducing protected text.
5. Require `THIRD-PARTY-NOTICES` or an equivalent notice file update when
   third-party text, examples, or vendored assets are copied into the repo.
6. Add reviewer guidance that treats copied restricted text, missing source
   class, missing attribution, and missing notice updates as blocking findings
   for risky-path PRs.

## Reviewer Contract

Licensing review should produce a compact finding record:

```text
source: <url-or-name>
source_class: <basecoat-owned|public-reference|open-source-compatible|vendor-guidance|restricted-standard|unknown>
usage: <cite-only|paraphrase|short-quote|vendored-copy>
notice_required: <yes|no>
notice_status: <present|missing|not-applicable>
decision: <allow|revise|block>
```

The default decision for `restricted-standard` with `short-quote` or
`vendored-copy` is `block`. The default decision for `unknown` source class is
`revise` or `block` until classification is documented.

## Failure Handling

- Unknown source class: do not copy the content; ask for source classification
  or replace with a BaseCoat-owned summary and citation.
- Restricted standard: remove copied text and retain only safe identifiers,
  citations, and original analysis.
- Missing notice: block the PR until the notice is added or the copied content
  is removed.
- Generated artifact copied from an issue or external source: preserve the
  source link and treat the quoted content as evidence, not reusable owned text.

## Testing and Rollout

Add validation or eval fixtures for:

- allowed citation-only reference to a restricted standard,
- blocked copied paragraph from a restricted standard,
- allowed paraphrase of vendor guidance with citation,
- copied open-source-compatible snippet with attribution and notice present,
- copied third-party snippet with missing notice blocked.

Roll out first as an instruction/reviewer contract. Follow-up implementation
can wire the contract into warn-rules or PR review automation.

## Acceptance Criteria

- [ ] Licensing-posture guidance defines source classes and allowed usage modes.
- [ ] Restricted standards are cite-only and cannot be copied into BaseCoat
  artifacts.
- [ ] Paraphrase-first handling is required for vendor and public-reference
  content unless direct quotation is short, necessary, and attributed.
- [ ] Third-party copied content requires attribution and a notice update when
  applicable.
- [ ] Reviewer guidance treats copied restricted text, missing source class, and
  missing required notice as blocking findings.
- [ ] Fixtures or evals cover allowed citation, blocked restricted copy,
  paraphrase-with-citation, notice-present copy, and notice-missing denial.
- [ ] Validation commands pass with no errors.
- [ ] PR references this spec.

## References

- PRD: `docs/prd/synthesized/issue-3115-governance-enhancement-add-iplicensing-posture-paraphrase-fi.prd.md`
- Refs #3115
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3115>
