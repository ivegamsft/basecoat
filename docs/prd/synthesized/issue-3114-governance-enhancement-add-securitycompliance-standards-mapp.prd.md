---
issue: 3114
title: "Governance enhancement: add security/compliance standards-mapping layer (OWASP/NIST/AI-RMF/WAF/CAF)"
status: draft
author: ibuyspy
created: 2026-09-07
labels: ["enhancement", "governance", "priority:low", "needs-triage", "needs-prd", "synthesize-spec"]
---

# PRD: Governance enhancement: add security/compliance standards-mapping layer (OWASP/NIST/AI-RMF/WAF/CAF)

## Problem Statement

**Gap (vs HVE):** HVE maps every component to OWASP/NIST/AI-RMF/WAF/CAF with explicit per-component gap analysis (`standards-mapping.instructions.md` + `security-planning` skill). basecoat references specific guardrails but has no formal standards crosswalk/gap-analysis artifact.

**Proposal:** Add an optional standards-mapping skill/instruction that crosswalks migration components to named standards and emits a coverage + gap report. Consider runtime lookup for volatile frameworks (WAF/CAF/PCI/FedRAMP).

**Existing partial coverage:** `security-operations`, `supply-chain-security`, `azure-policy-audit` skills.

Refs benchmark analysis. Parent: #3113

## Why This Matters

BaseCoat already includes many security and cloud-governance assets, but users
cannot quickly tell which recognized standards are covered, which controls are
only advisory, and where gaps remain. A standards crosswalk gives reviewers and
downstream adopters a durable map from BaseCoat capabilities to common
framework expectations without implying certification or legal compliance.

## Scope

In scope:

- Define a standards-mapping artifact model for BaseCoat assets covering at
  least OWASP, NIST, Microsoft CAF/WAF, and AI RMF categories.
- Add a standards-mapping skill or instruction workflow that produces a coverage
  and gap report for a repository, migration plan, or agent/skill bundle.
- Reuse existing security, supply-chain, Azure policy, and governance assets as
  evidence rather than duplicating control text.
- Include freshness guidance for volatile external frameworks so stale mappings
  are visible.

Out of scope:

- Claiming formal compliance, certification, or audit readiness.
- Copying restricted standards text into BaseCoat.
- Replacing existing security review, WAF review, or Azure policy skills.

## Success Criteria

- [ ] A first-class mapping surface exists and can report covered, partial, and
  missing standards categories.
- [ ] The mapping references BaseCoat assets by path and capability rather than
  reproducing restricted framework text.
- [ ] The report includes explicit caveats that mappings are advisory and not a
  compliance attestation.
- [ ] Tests or validation fixtures prove the mapping detects at least one
  covered category and one intentional gap.

## References

- Refs #3114
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3114>
