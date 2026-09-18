# Product Requirements Document: Re-Scope Always-On Instructions by Load Timing

> **Status:** Draft  
> **Issue:** #2975  
> **Author:** Copilot  
> **Sprint:** 2026-W36  
> **Target Version:** v4.2.0  
> **Last Updated:** 2026-09-02  

---

## 1. Problem Statement

BaseCoat currently configures 34 of its 91 instruction files with global scope (`applyTo: "**/*"`), causing approximately 39,780 tokens (~133 KB) of instruction content to load unconditionally on every single agent turn. In real-world downstream consumers (such as `IBuySpy-Dev/ibuypets-v3`), the always-on set expands to 43 files (~47.4k tokens, ~43% of the total instruction corpus), polluting context across specialized backend (`.cs`), infrastructure (`.bicep`), and database (`.sql`) edits.

This hot-context overhead contradicts BaseCoat's own token-economics and tool-minimization guidance, inflates per-turn latency and inference costs, and starves agents of working memory for task code. By contrast, the sibling HVE framework maintains only ~5.6k always-on tokens (~3.5% of total corpus) by strictly partitioning instructions by load timing (path/file globs and on-demand skills).

---

## 2. Goals

1. **Reclaim Hot Context:** Reduce cumulative always-on (`applyTo: "**/*"`) instructions from ~40k tokens to <= 12k tokens, reclaiming ~30k-40k tokens of working context per turn across all downstream repositories.
2. **Implement Load-Timing Taxonomy:** Re-classify all BaseCoat instructions into four discrete load-timing tiers: Universal Always-On, Domain/Path-Scoped, On-Demand Skills, and Subagent-Specialized.
3. **Automate Regression Guardrails:** Introduce an automated CI check that calculates total tokens across all `applyTo: "**/*"` instructions and fails if cumulative tokens exceed the 12k budget ceiling.
4. **Preserve Capability & Consistency:** Ensure 100% functional guidance remains accessible when relevant, making BaseCoat self-consistent with its own token-frugality principles.

---

## 3. Non-Goals

1. **Deleting Guidance Content:** No existing guidance or cognitive-architecture instructions will be deleted; content is moved to scoped globs or on-demand skills so it loads only when relevant.
2. **Modifying Agent Prompt Bodies:** Agent system prompts (`agents/*.agent.md`) remain untouched in this initiative.
3. **Changing Downstream Workflow Distribution Mechanics:** The core synchronization pipeline (`sync.ps1`, `sync.sh`) will distribute assets according to frontmatter without requiring changes to underlying deployment scripts.

---

## 4. Users and Stakeholders

| Persona | Need | Priority |
|---|---|---|
| **Downstream Developer / Agent** | Maximum available context window for code and task reasoning; lower latency per turn | High |
| **Repository Maintainer** | Automated CI guardrails to prevent token bloat regression in pull requests | High |
| **Asset Author** | Clear conventions for choosing `applyTo` patterns vs on-demand skills | Medium |
| **Enterprise Platform Lead** | Predictable token economics, reduced inference billing across fleet repositories | High |

---

## 5. User Personas and Use Cases

### User Personas

- **Autonomous Agent (Copilot SWE / Cloud Agent):** Operates on repository files across various tech stacks. Needs focused instructions relevant to the active file types rather than monolithic cognitive frameworks on every turn.
- **BaseCoat Contributor:** Authors or updates instruction files. Needs clear guardrails and linting tools to ensure new instructions do not accidentally inflate global context.
- **Downstream Consumer Lead:** Consumes BaseCoat assets via sync. Needs guaranteed light initial footprint with deep guidance available on demand.

### Use Cases

- **Backend / IaC Edit:** An agent edits a `.cs` or `.bicep` file. Only C# / Bicep rules and universal safety invariants load; frontend, notebook, and orchestration instructions remain unloaded.
- **Complex Architecture / Routing Task:** An agent needs high-level routing or cognitive reflexions; it invokes on-demand skills or edits architectural docs, loading the relevant instructions dynamically.
- **PR CI Validation:** A PR introduces a new instruction file. CI validates that global always-on token usage does not exceed 12,000 tokens.

---

## 6. Functional Requirements

### P0 — Must Have

| ID | Requirement | Description |
|---|---|---|
| FR-1 | Cognitive Layer Re-scoping | Move cognitive-architecture files (`hrm-execution`, `trm-reflexion`, `memory-index`, `intent-routing`, `model-routing`, `shearing-layers`, `session-hygiene`) out of `applyTo: "**/*"`. |
| FR-2 | Task / Skill Conversion | Convert purely task-triggered cognitive layers into on-demand skills or path-scoped documentation guides. |
| FR-3 | Path & Language Glob Scoping | Restrict domain-specific instructions (e.g. testing, frontend, backend, UX, workflow) to specific directory and file extension globs. |
| FR-4 | Universal Rule Audit | Audit retained always-on files (e.g. LOG-FIRST, secrets safety, minimal output style) and condense to concise invariant checklists. |
| FR-5 | CI Token Budget Guardrail | Implement an automated test/script in CI that calculates total tokens in all `applyTo: "**/*"` files and asserts total <= 12,000 tokens. |
| FR-6 | Compatibility Alias Alignment | Ensure non-prefixed compatibility alias stubs mirror canonical instruction scopes without body duplication. |

### P1 — Should Have

| ID | Requirement | Description |
|---|---|---|
| FR-7 | Frontmatter Distribute Flag Audit | Ensure internal-only instruction files marked `distribute: false` are excluded from consumer overlays or properly isolated. |
| FR-8 | Token Inventory Reporting | Update `scripts/generate-token-context-inventory.py` to report hot always-on token metrics alongside total corpus size. |
| FR-9 | Downstream Smoke Verification | Validate consumer synchronization in `run-consumer-smoke.ps1` to ensure downstream repos receive correct scoped instruction sets. |

### P2 — Nice to Have

| ID | Requirement | Description |
|---|---|---|
| FR-10 | Per-Instruction Token Budget Warning | Add per-file advisory warnings in `validate-basecoat.ps1` for any individual always-on instruction exceeding 1,000 tokens. |
| FR-11 | Token Savings Telemetry | Add telemetry or scorecard metrics reflecting turn token savings across sample tasks. |

---

## 7. Non-Functional Requirements

| ID | Requirement | Notes |
|---|---|---|
| NFR-1 | **Token Budget Constraint** | Cumulative always-on tokens (`applyTo: "**/*"`) must not exceed **12,000 tokens** (~48 KB raw text). Target: ~8,000 to 10,000 tokens. |
| NFR-2 | **Zero Regression in Test Coverage** | All existing guardrails, routing tests, and validation scripts (`validate-basecoat.ps1`, `run-tests.ps1`) must pass. |
| NFR-3 | **Markdown & Style Compliance** | All modified and new documentation must satisfy `.markdownlint.json` and contain zero emojis. |
| NFR-4 | **Deterministic Evaluation** | Token budget validation must execute deterministically in CI in under 5 seconds without external API calls. |

---

## 8. User Stories

- **As an AI coding agent**, I want only universal rules and relevant file-type instructions in my prompt context, so that I have maximum context space for source code and issue resolution.
- **As a repository maintainer**, I want pull requests to fail CI if always-on instructions exceed 12k tokens, so that team members do not inadvertently regress context frugality.
- **As a platform architect**, I want BaseCoat to match the HVE load-timing design pattern, so that multi-repo fleet operations remain cost-efficient.

---

## 9. Acceptance Criteria

- [ ] **AC-1:** Given the upstream `instructions/` directory, when analyzing all files with `applyTo: "**/*"`, the total estimated token count is <= 12,000 tokens.
- [ ] **AC-2:** Given cognitive-architecture instructions (`hrm-execution`, `trm-reflexion`, `memory-index`, `intent-routing`, `model-routing`, `shearing-layers`, `session-hygiene`), each file uses either a specific path/file glob or is converted to an on-demand skill.
- [ ] **AC-3:** Given language- and domain-specific instructions (`testing`, `development`, `subagent-review`, `quality`, `ai-verification`), each file is scoped to relevant extensions (`**/*.{ts,tsx,js,jsx,cs,py,go,java,bicep,tf}`) or paths (`tests/**`, `src/**`).
- [ ] **AC-4:** Given a CI pull request validation run, when a new instruction with `applyTo: "**/*"` causes cumulative tokens to exceed 12,000, the CI step fails with an actionable error message.
- [ ] **AC-5:** Given downstream consumer synchronization via `sync.ps1` and `sync.sh`, all scoped instruction files retain valid YAML frontmatter and proper path resolution.
- [ ] **AC-6:** All BaseCoat tests (`pwsh scripts/validate-basecoat.ps1` and `pwsh tests/run-tests.ps1`) pass with zero errors.

---

## 10. Technical Approach and Architecture

### 10.1 Load-Timing Taxonomy

BaseCoat instructions will be organized into four distinct operational tiers:

```text
+-------------------------------------------------------------------------+
| Tier 0: Universal Invariants (applyTo: "**/*")                           |
| Budget: <= 12k tokens total (~6-8 files)                                |
| Scope: Hard safety, security boundaries, LOG-FIRST, core output style   |
+-------------------------------------------------------------------------+
                                    |
+-------------------------------------------------------------------------+
| Tier 1: Domain & Path Scoped (applyTo: "src/**,**/*.{ext}")             |
| Budget: Unconstrained globally (loads only when relevant files are open)|
| Scope: Language conventions, testing frameworks, IaC, web UI           |
+-------------------------------------------------------------------------+
                                    |
+-------------------------------------------------------------------------+
| Tier 2: Task-Triggered Skills (skills/<name>/SKILL.md)                  |
| Budget: Zero baseline context (loaded on demand via skill invocation)   |
| Scope: HRM execution, TRM reflexion, deep memory management, triage    |
+-------------------------------------------------------------------------+
                                    |
+-------------------------------------------------------------------------+
| Tier 3: Subagent Specialized (agents/*.agent.md)                        |
| Budget: Isolated to dedicated subagent context windows                  |
| Scope: Specialist reviews, security audits, release management          |
+-------------------------------------------------------------------------+
```

### 10.2 Instruction File Re-Scoping Plan

The 34 current always-on instruction files will be re-scoped as follows:

| Current Always-On Instruction | Size (bytes) | Est. Tokens | Target Scope / Action |
|---|---|---|---|
| `basecoat-10-core-agent-behavior.instructions.md` | 4,731 | 1,345 | Scoped: `agents/**/*.agent.md,skills/**/SKILL.md,.github/instructions/**/*` |
| `basecoat-10-core-agent-routing.instructions.md` | 7,581 | 1,957 | Scoped: `agents/**/*.agent.md,.github/**/*,docs/**/*` |
| `basecoat-10-core-development.instructions.md` | 5,805 | 1,462 | Scoped: `src/**,lib/**,app/**,packages/**,api/**,server/**,tests/**` |
| `basecoat-10-core-documentation.instructions.md` | 2,880 | 677 | Scoped: `**/*.md,docs/**` |
| `basecoat-10-core-escalation-criteria.instructions.md` | 1,562 | 422 | Retained Always-On (Universal Escalation Invariants) |
| `basecoat-10-core-hrm-execution.instructions.md` | 6,749 | 1,717 | On-Demand Skill / Scoped: `docs/plans/**,docs/design/**,.github/workflows/**` |
| `basecoat-10-core-intent-routing.instructions.md` | 24,025 | 5,369 | Scoped: `.github/**/*,docs/**/*,agents/**/*.agent.md` (or on-demand routing skill) |
| `basecoat-10-core-memory-index.instructions.md` | 7,973 | 2,032 | On-Demand Skill (`skills/memory-index/`) / Scoped: `scripts/*memory*.ps1` |
| `basecoat-10-core-model-routing.instructions.md` | 4,563 | 1,124 | Scoped: `agents/**/*.agent.md,.github/workflows/**` |
| `basecoat-10-core-output-style.instructions.md` | 1,552 | 413 | Retained Always-On (Universal Formatting Invariants) |
| `basecoat-10-core-plan-first.instructions.md` | 4,156 | 1,073 | Retained Always-On (Core Planning Guardrail) or Scoped |
| `basecoat-10-core-process.instructions.md` | 4,016 | 935 | Scoped: `.github/**/*,docs/process/**,**/*.md` |
| `basecoat-10-core-public-guidance.instructions.md` | 1,874 | 468 | Retained Always-On (Public Safety & Boundary Rules) |
| `basecoat-10-core-session-hygiene.instructions.md` | 3,353 | 862 | Scoped / On-Demand: `docs/guides/**,.github/**/*` |
| `basecoat-10-core-shearing-layers.instructions.md` | 3,687 | 930 | Scoped: `docs/architecture/**,docs/adr/**,src/**,lib/**` |
| `basecoat-10-core-subagent-review.instructions.md` | 4,096 | 1,064 | Scoped: `agents/**/*.agent.md,tests/**` |
| `basecoat-10-core-testing.instructions.md` | 4,073 | 981 | Scoped: `tests/**,test/**,specs/**,**/*.test.*,**/*.spec.*,**/*-tests.ps1` |
| `basecoat-10-core-tool-minimization.instructions.md` | 3,816 | 1,017 | Retained Always-On (Universal Tool Budget Invariants) |
| `basecoat-10-core-trm-reflexion.instructions.md` | 5,168 | 1,379 | On-Demand Skill / Scoped: `docs/plans/**,tests/**` |
| `basecoat-10-core-verification.instructions.md` | 1,855 | 476 | Scoped: `tests/**,scripts/validate-*,scripts/verify-*` |
| `basecoat-20-lang-governance.instructions.md` | 8,170 | 1,681 | Retained Always-On (LOG-FIRST hard gate) or split into core invariant + detailed doc |
| `basecoat-30-ai-ai-verification.instructions.md` | 4,328 | 1,149 | Scoped: `tests/evals/**,scripts/eval-*,tests/behavioral*` |
| `basecoat-50-security-security.instructions.md` | 4,590 | 1,035 | Retained Always-On (Universal Secrets & Security Invariants) |
| `basecoat-50-security-token-economics.instructions.md` | 3,122 | 724 | Scoped: `docs/**/*,.github/instructions/**/*,scripts/*token*` |
| `basecoat-60-workflow-high-stakes-workflow.instructions.md` | 3,091 | 779 | Scoped: `.github/workflows/**,scripts/ship-it/**` |
| `basecoat-90-quality-quality.instructions.md` | 3,118 | 765 | Scoped: `src/**,lib/**,tests/**,docs/**` |
| Compatibility Aliases (8 files) | ~3,000 | ~480 | Update to mirror canonical scopes |

### 10.3 Token Budget CI Check Design

A new PowerShell verification script `scripts/validate-instruction-token-budget.ps1` (integrated into `validate-basecoat.ps1` and `tests/routing-guardrail-tests.ps1`) will enforce:

1. Scan all `instructions/*.instructions.md` and `.github/instructions/*.instructions.md`.
2. Extract frontmatter `applyTo` field.
3. Identify files matching `applyTo: "**/*"` (or broad wildcard patterns).
4. Estimate tokens using the standard formula (`wordCount * 1.7` or `charCount / 4`).
5. Assert that the cumulative sum of always-on tokens is <= 12,000 tokens.
6. Fail the build with a detailed itemized breakdown if the threshold is breached.

---

## 11. Technical Specification

### 11.1 Context & Background

In the GitHub Copilot Agent runtime, instruction files matching the current working set or glob patterns are prepended to the model context on every turn. When `applyTo: "**/*"` is specified, that instruction is permanently pinned into the conversation turn regardless of whether the agent is writing a unit test, updating a Bicep template, or editing documentation.

Over successive releases, BaseCoat's core instruction suite accumulated 34 globally scoped files. Because each file contains extensive examples, procedural checklists, and markdown tables, the baseline payload reached ~40k tokens. In a standard 128k or 200k context model, this consumes 20% to 35% of the total available reasoning capacity before the first user message or file content is loaded.

### 11.2 Architectural Invariants

1. **Deterministic Loading:** Instructions must load exclusively when the files they govern are in active scope.
2. **Universal Invariant Minimization:** Only true invariants (such as LOG-FIRST tracking issue requirements and secret scanning rules) remain always-on, and their token length must be strictly budgeted.
3. **Zero Downstream Breaking Changes:** Scoped globs must cover standard enterprise project layouts (`src/`, `lib/`, `app/`, `packages/`, `api/`, `tests/`, `iac/`).

### 11.3 CI Enforcement Algorithm

```pseudo
function Check-InstructionTokenBudget(directory, tokenCeiling = 12000):
    alwaysOnTokens = 0
    alwaysOnList = []

    for file in directory.GetFiles("*.instructions.md"):
        applyTo = ExtractFrontmatterField(file, "applyTo")
        if IsBroadWildcard(applyTo):
            tokens = EstimateTokens(file.Content)
            alwaysOnTokens += tokens
            alwaysOnList.Append({ file.Name, tokens })

    if alwaysOnTokens > tokenCeiling:
        LogError("Cumulative always-on tokens ({alwaysOnTokens}) exceeds budget ({tokenCeiling})")
        PrintBreakdown(alwaysOnList)
        return Failure
    
    LogSuccess("Always-on tokens ({alwaysOnTokens}) within budget ({tokenCeiling})")
    return Success
```

---

## 12. Files Affected

```text
instructions/
  basecoat-10-core-agent-behavior.instructions.md
  basecoat-10-core-agent-routing.instructions.md
  basecoat-10-core-development.instructions.md
  basecoat-10-core-documentation.instructions.md
  basecoat-10-core-hrm-execution.instructions.md
  basecoat-10-core-intent-routing.instructions.md
  basecoat-10-core-memory-index.instructions.md
  basecoat-10-core-model-routing.instructions.md
  basecoat-10-core-process.instructions.md
  basecoat-10-core-session-hygiene.instructions.md
  basecoat-10-core-shearing-layers.instructions.md
  basecoat-10-core-subagent-review.instructions.md
  basecoat-10-core-testing.instructions.md
  basecoat-10-core-trm-reflexion.instructions.md
  basecoat-10-core-verification.instructions.md
  basecoat-30-ai-ai-verification.instructions.md
  basecoat-50-security-token-economics.instructions.md
  basecoat-60-workflow-high-stakes-workflow.instructions.md
  basecoat-90-quality-quality.instructions.md
  architecture.instructions.md
  documentation.instructions.md
  governance.instructions.md
  intent-routing.instructions.md
  observability.instructions.md
  plan-first.instructions.md
  security.instructions.md
  ux.instructions.md
scripts/
  lint-applyto-scope.ps1
  validate-basecoat.ps1
  generate-asset-manifest.ps1
tests/
  routing-guardrail-tests.ps1
  token-cost-compare-tests.ps1
docs/
  design/re-scope-always-on-instructions-prd.md
  guides/prd-and-spec-guidance.md
```

---

## 13. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Agent misses critical rule during multi-stack edits** | Low | Medium | Ensure broad globs cover multi-language patterns (e.g., `src/**,lib/**,**/*.{ts,cs,py}`) and universal safety rules remain in Tier 0. |
| **Downstream consumer sync issues** | Low | High | Validate both `sync.ps1` and `sync.sh` against consumer test harnesses (`tests/sync-tests.ps1`, `tests/run-consumer-smoke.ps1`). |
| **Silent token budget drift in future PRs** | High | High | Enforce hard failure in CI via `validate-basecoat.ps1` and `tests/routing-guardrail-tests.ps1`. |

---

## 14. Open Questions

- [ ] **Q-1:** Should `basecoat-10-core-intent-routing` be migrated entirely to an on-demand skill (`skills/intent-routing/`) or scoped to orchestration files (`.github/**/*,docs/**/*`)?  
  *Recommendation:* Scope to `.github/**/*,docs/**/*,agents/**/*.agent.md` initially, with an on-demand skill wrapper.
- [ ] **Q-2:** What exact token ceiling should CI enforce (e.g. 10,000 vs 12,000 tokens)?  
  *Recommendation:* Set 12,000 tokens as the hard CI ceiling with an advisory target of 10,000 tokens.

---

## 15. Milestones and Rollout Plan

| Milestone | Target | Description |
|---|---|---|
| **M1: PRD & Spec Publication** | Sprint 2026-W36 | PRD approved and linked in issue #2975 and tracking PR. |
| **M2: Core Instruction Re-scoping** | Sprint 2026-W36 | Re-scope 27 non-invariant instruction files to specific globs and skills. |
| **M3: Universal Invariant Audit** | Sprint 2026-W36 | Streamline retained Tier 0 files (LOG-FIRST, secrets, output style) under 10k tokens total. |
| **M4: CI Guardrail Implementation** | Sprint 2026-W36 | Add token budget validation script and integrate into `run-tests.ps1`. |
| **M5: Downstream Verification** | Sprint 2026-W37 | Run consumer smoke tests against `ibuypets-v3` and verify ~40k token savings. |

---

## 16. Appendix

### 16.1 Comparative Footprint Analysis

| Metric | BaseCoat (Current) | HVE Framework | BaseCoat (Target) |
|---|---|---|---|
| Total Instruction Files | 91 | 110 | 91 |
| Always-On Files (`applyTo: "**/*"`) | 34 (37.4%) | 4 (3.6%) | <= 7 (7.7%) |
| Always-On Raw Size (KB) | ~133 KB | ~18 KB | <= 38 KB |
| Always-On Estimated Tokens | ~39,780 | ~5,600 | <= 12,000 |
| Hot Context Percentage | ~43% | ~3.5% | <= 9.0% |

### 16.2 References

- Tracking Issue: [IBuySpy-Shared/basecoat#2975](https://github.com/IBuySpy-Shared/basecoat/issues/2975)
- PRD Template: `docs/templates/prd-template.md`
- Token Economics Reference: `instructions/references/token-economics/context-routing.md`
- Session Hygiene Reference: `docs/guides/phase-boundary-session-checklist.md`
