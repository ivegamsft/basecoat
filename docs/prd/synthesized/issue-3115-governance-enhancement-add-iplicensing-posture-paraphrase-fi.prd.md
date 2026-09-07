---
issue: 3115
title: "Governance enhancement: add IP/licensing posture (paraphrase-first, THIRD-PARTY-NOTICES, cite-only restricted standards)"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governance enhancement: add IP/licensing posture (paraphrase-first, THIRD-PARTY-NOTICES, cite-only restricted standards)

## Problem Statement

**Gap (vs HVE):** HVE ships a first-class `licensing-posture.instructions.md` (source classes, paraphrase-first default, THIRD-PARTY-NOTICES requirement, cite-only for ISO/IEC/ETSI) enforced as gating review findings. basecoat has no equivalent IP/attribution layer for vendored/quoted reference text.

**Proposal:** Add a licensing-posture instruction + reviewer check governing reproduction/attribution of upstream standards text in skills and docs.

**Existing partial coverage:** none first-class.

Parent: #3113

## Why This Matters

BaseCoat agents, skills, and docs may summarize upstream standards, vendor
guidance, public articles, and third-party examples. Without a first-class
licensing posture, contributors can accidentally copy restricted text, omit
required attribution, or mix externally sourced content into BaseCoat-owned
guidance without a durable notice trail.

The repository needs a practical default: paraphrase first, cite sources
instead of reproducing restricted material, and record third-party notices when
vendored or quoted content is intentionally included.

## Scope

In scope:

- Add a licensing-posture instruction for docs, agents, skills, prompts, and
  generated artifacts that ingest or summarize third-party content.
- Define source classes, including BaseCoat-owned text, public documentation,
  open-source licensed content, vendor guidance, standards bodies, and
  restricted/licensed standards.
- Establish paraphrase-first handling for external content and cite-only
  handling for restricted standards text such as ISO, IEC, ETSI, and similar
  paywalled or license-controlled materials.
- Require attribution and `THIRD-PARTY-NOTICES` updates when third-party text,
  examples, or vendored material are copied with permission.
- Add reviewer guidance or validation coverage that flags copied restricted
  text, missing attribution, and missing notice updates.

Out of scope:

- Providing legal advice or determining license compatibility for every
  possible upstream source.
- Replacing repository license review by maintainers.
- Requiring notices for ordinary references that only cite a source by name or
  public URL without copying protected text.

## Success Criteria

- [ ] Contributors have a clear source-class model for third-party content.
- [ ] BaseCoat defaults to paraphrasing and citation rather than copying
  upstream standards or vendor text.
- [ ] Restricted standards are handled with cite-only references and BaseCoat-
  owned summaries.
- [ ] Reviewer or validation coverage detects copied restricted text and missing
  attribution/notice updates.

## References

- Refs #3115
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3115>
