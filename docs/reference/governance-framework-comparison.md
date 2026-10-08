# Governance Approach: basecoat vs HVE

This document records how basecoat and [HVE Core](https://github.com/microsoft/hve-core)
approach **governance**, based on each framework's shipped assets. It was produced during the
AI-SDLC criss-cross benchmark (basecoat vs HVE migrating the same legacy apps) so the two
governance models can be compared fairly and so gaps can be triaged as enhancements.

The two frameworks are not weaker/stronger versions of one model — they govern **different objects**
at **different points** in the lifecycle. Understanding that difference is the point of this doc.

## Summary

- **basecoat — operational, enforcement-first, always-on.** Governance is a set of hard runtime
  rules the agent must satisfy *before any side-effecting action*, plus explicit cost/model
  governance and a large fleet of point-in-time audit skills.
- **HVE — artifact-driven, lifecycle and compliance posture.** Governance is distributed across the
  Research → Plan → Implement → Review lifecycle via specialized planner/reviewer agents, standards
  crosswalks, IP/licensing posture, an untrusted-content boundary, and a durable provenance trail.

## basecoat: operational, enforcement-first

| Aspect | Detail |
|---|---|
| Canonical rulebook | `instructions/basecoat-20-lang-governance.instructions.md` (`applyTo: **/*`, `priority: 1`) — always-on, self-blocking hard rules |
| Core hard rules | LOG-FIRST issue gate, PR-only (no direct `main`), no-secrets, OIDC federation, container SHA tags, CAF naming, `.env.example`, DB-migration concurrency, batch-PR size caps |
| Cost/model governance | Explicit — `basecoat-10-core-model-routing`, `basecoat-50-security-token-economics`, `s4-safety-gates`, `escalation-criteria`, `high-stakes-workflow`, `drift-monitor` |
| Audit model | Point-in-time posture scans via `*-audit` skills (governance-audit, ci-audit, security-operations, supply-chain-security, landing-zone-audit, release-audit, project-rules-drift-audit, …) |
| Governance-as-contract | `skills/governance` maintains a canonical governance-contract + label taxonomy separating shared from repo-specific rules |
| Locus of enforcement | Runtime; the agent blocks itself before acting |

## HVE: artifact-driven, compliance and provenance

| Aspect | Detail |
|---|---|
| Canonical rulebook | None single/always-on — governance is distributed across RPI phases and reviewer agents |
| Standards mapping | `.github/instructions/security/standards-mapping.instructions.md` — components crosswalked to OWASP/NIST/AI-RMF, runtime research for WAF/CAF/PCI/FedRAMP/SLSA/S2C2F, explicit gap analysis |
| IP/licensing posture | `.github/instructions/hve-core/licensing-posture.instructions.md` — source classes, paraphrase-first default, `THIRD-PARTY-NOTICES`, cite-only for restricted standards (ISO/IEC/ETSI); violations gate at review |
| Untrusted-content boundary | `.github/instructions/shared/untrusted-content-boundary.instructions.md` — external content is data, not instructions; non-overridable authority anchor |
| Human-review gates | `.github/instructions/project-planning/backlog-guardrails.instructions.md` — three-tier autonomy model + review checkboxes before any tracker-bound mutation |
| RAI / privacy | Dedicated RAI and privacy planner/reviewer agents produce plan + review artifacts |
| Provenance model | Durable per-task evidence trail under `.copilot-tracking/` (research/plans/details/changes/reviews) with stable IDs; "file-based tracking takes precedence over memory" |
| Locus of enforcement | Authoring/review time; reviewer agents raise gating findings |

## Side-by-side

| Dimension | basecoat | HVE |
|---|---|---|
| Locus of enforcement | Runtime, agent self-blocks pre-action | Phase-gated authoring/review by reviewer agents |
| Primary object governed | Operational workflow (issues, PRs, secrets, Azure/CI guardrails) | SDLC artifacts + external inputs (standards, IP, RAI, injection) |
| Structure | Centralized canonical instruction + contract + audit-skill fleet | Decentralized overlays scoped by `applyTo` path globs, deferring to a single skill definition |
| Cost/model governance | Explicit (token-economics, model-routing tiers) | None operational — native routing |
| Standards/compliance depth | Named guardrails with doc refs; light on formal crosswalks | Deep: OWASP/NIST/AI-RMF/WAF/CAF mapping + gap analysis |
| IP/licensing and RAI/privacy | Not a first-class layer | First-class (licensing-posture, RAI/privacy planners) |
| Auditability model | Point-in-time posture scans (audit skills) | Continuous per-task evidence trail |
| Human-in-the-loop | Escalation criteria / safety gates | Autonomy tiers + explicit review checkboxes |

## Benchmark implication

The criss-cross benchmark metrics schema originally scored governance with fields
(`iac_only`, `actions_sha_pinned_pct`, `rollback_exercised`, `driver_mechanism`, `chosen_*`) that map
almost 1:1 onto basecoat's operational rules, and so under-measured HVE's compliance/provenance
strengths. The schema's `governance` block was extended with framework-neutral fields
(`cost_governance_present`, `standards_coverage_pct`, `compliance_frameworks_mapped`,
`licensing_findings`, `rai_privacy_plan_present`, `human_review_gates`, `provenance_artifacts`,
`untrusted_content_boundary_enforced`) so both models are captured. Conversely, only basecoat exposes
explicit cost/model governance, which is the cost-governance delta the benchmark's as-configured arm
quantifies.

## Enhancement candidates (logged for triage)

Areas where basecoat could adopt or strengthen HVE-style governance strengths. Each is filed as a
`needs-triage` enhancement:

| Candidate | Issue |
|---|---|
| Security/compliance standards-mapping layer (OWASP/NIST/AI-RMF/WAF/CAF) | [#3114](internal source issue) |
| IP/licensing posture (paraphrase-first, THIRD-PARTY-NOTICES, cite-only) | [#3115](internal source issue) |
| Responsible-AI + privacy planning/review agents | [#3116](internal source issue) |
| Untrusted-content / prompt-injection boundary instruction | [#3117](internal source issue) |
| Durable per-task provenance/evidence trail | [#3118](internal source issue) |
| Human-review gates / autonomy tiers on tracker-bound mutations | [#3119](internal source issue) |

Tracking issue: [#3113](internal source issue).

## References

| Topic | File |
|---|---|
| basecoat governance rules | [`basecoat-20-lang-governance.instructions.md`](../../instructions/basecoat-20-lang-governance.instructions.md) |
| basecoat governance contract | [`governance.md`](governance.md), [`governance-contract.md`](governance-contract.md) |
| HVE standards mapping | `microsoft/hve-core` — `.github/instructions/security/standards-mapping.instructions.md` |
| HVE licensing posture | `microsoft/hve-core` — `.github/instructions/hve-core/licensing-posture.instructions.md` |
| HVE untrusted-content boundary | `microsoft/hve-core` — `.github/instructions/shared/untrusted-content-boundary.instructions.md` |
| HVE backlog guardrails | `microsoft/hve-core` — `.github/instructions/project-planning/backlog-guardrails.instructions.md` |
