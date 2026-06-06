---
description: "Sprint 32: Docs deduplication and cleanup"
---

# Sprint 32: Docs Deduplication & Organization

**Sprint ID**: 32  
**Duration**: 2 weeks  
**Start**: 2026-06-06  
**Goals:**

- Fix 13 broken cross-references in docs (critical for mkdocs build)
- Delete 18 obsolete UPPERCASE redirect files
- Rename 8 UPPERCASE reference files to lowercase (naming consistency)
- Clarify templates vs. examples taxonomy
- Polish: rename generic README.md files

**Focus**: Filesystem cleanup + naming consistency + organization structure

---

## P1 Blockers (Critical Path)

Must complete in sequence (Phase 1):

- **#1368**: Fix 13 broken cross-references (BEFORE deleting redirects)
  - Owner: @ibuyspy
  - Files: docs/agents/AGENTS.md, behavioral-eval.md, agent-testing-harness.md (5 agents), docs/memory/index.md, shared-memory.md, triage.md, CONTRIBUTING.md, docs/operations/telemetry-adoption.md
  - Refs: Update UPPERCASE filename refs to lowercase
  - Est. effort: 30 min (find/replace + verification)
  - Verification: `python -m mkdocs build --strict` must pass

- **#1367**: Delete 18 UPPERCASE redirect files
  - Owner: @ibuyspy
  - Files: MODEL_OPTIMIZATION.md, RELEASE_PROCESS.md, TELEMETRY_ADOPTION_PHASE1.md, OPERATIONAL_RUNBOOK.md, SECRET_SCANNING.md, BRANCH_PROTECTION.md, ENTERPRISE_SECURITY_HARDENING.md, SQLITE_MEMORY.md, MEMORY_DESIGN.md, LEARNING_MODEL.md, SHARED_MEMORY_GUIDE.md, QUICK_REFERENCE.md, TOKEN_CONTEXT_INVENTORY.md, AGENT_TESTING_HARNESS.md, CONTEXT_ASSEMBLY_CONTRACT.md, BEHAVIORAL_EVAL.md, VS_CODE_HARNESS_BENCHMARKS.md, TOOLS_UI_CHAT_DEBUG_RUNBOOK.md
  - Est. effort: 15 min (git rm 18 files + verification)
  - Verification: `python -m mkdocs build --strict` must pass

---

## P2 Medium (Important)

Unblock after Phase 1:

- **#1369**: Rename 8 UPPERCASE reference files to lowercase
  - Owner: @ibuyspy
  - Files: AGENTS.md→agents.md, TAXONOMY.md→taxonomy.md, MODEL-DISTRIBUTION.md→model-distribution.md, AGENT_RUNTIME_ENFORCEMENT.md→agent-runtime-enforcement.md, INVENTORY.md→inventory.md, GOVERNANCE.md→governance.md, DISTRIBUTION.md→distribution.md, HOOKS.md→hooks.md, PRODUCT.md→product.md
  - Est. effort: 20 min (git mv × 8 + verification)
  - Verification: `python -m mkdocs build --strict` must pass

- **#1370**: Clarify and reorganize templates vs. examples taxonomy
  - Owner: @ibuyspy
  - Issue: docs/templates/ has project scaffolds (basecoat-memory, repo-template) mixed with file templates
  - Actions:
    1. Document distinction in docs/templates/README.md and docs/examples/README.md
    2. Decide: keep project scaffolds in docs/templates/ OR move to .github/template-repos/?
    3. Update navigation if needed
  - Est. effort: 30 min (documentation + decision)

---

## P3 Low (Polish)

After Phase 2:

- **#1371**: Rename 4 generic README.md files to be descriptive
  - Owner: @ibuyspy
  - Files:
    - docs/templates/basecoat-memory/README.md → basecoat-shared-memory-setup.md
    - docs/examples/repo-template/README.md → repo-template-quick-start.md
    - docs/examples/iac/README.md → iac-examples-index.md
    - docs/diagrams/README.md → architecture-diagrams-index.md
  - Est. effort: 15 min (rename + update any internal links)

---

## Changes from Sprint 31

### Moved In

- #1368, #1367: Critical docs fixes (discovered in audit, blocking mkdocs build integrity)
- #1369, #1370, #1371: Docs cleanup (identified as high ROI: filesystem hygiene, naming consistency, reduced confusion)

### Moved Out

- No items deferred; Sprint 31 cost-optimization work is complete and tracked

### Reordered

- N/A (first sprint with docs cleanup focus)

---

## Execution Plan

### Phase 1 (Critical) — Day 1, ~45 min

1. Start with #1368 (fix broken links first — critical blocker)
2. Then #1367 (delete redirects after links are fixed)
3. Verify: `python -m mkdocs build --strict`

### Phase 2 (Important) — Day 2-3, ~50 min

1. #1369 (rename UPPERCASE files to lowercase)
2. #1370 (clarify taxonomy)
3. Verify: `python -m mkdocs build --strict`

### Phase 3 (Polish) — Day 3-4, ~15 min

1. #1371 (rename generic READMEs)
2. Final verification: all tests pass, all cross-references valid

### Parallel Work

- None — docs cleanup is sequential due to dependency chain

---

## Metrics & Success Criteria

**Quantitative:**

- 18 UPPERCASE redirect files deleted
- 13 broken cross-references fixed
- 8 UPPERCASE files renamed to lowercase
- 4 generic README.md files renamed
- 0 broken links in mkdocs build

**Qualitative:**

- All filenames follow lowercase convention
- Templates vs. examples taxonomy clearly documented
- No redirect chains in filesystem

**Verification:**

- `python -m mkdocs build --strict` must pass (no warnings about docs/*)
- `pwsh scripts/validate-basecoat.ps1` must pass (structure validation)
- `git status` must be clean (no stray files)

---

## Notes

- This sprint focuses on **filesystem hygiene** and **naming consistency**, not feature delivery
- All work is mechanical (find/replace, git mv/rm) — low risk of regressions
- Estimated total effort: **1.5–2 hours** (plus verification time)
- Follow Phase 1 → Phase 2 → Phase 3 sequence strictly (dependencies)
- After each phase, commit and verify docs build before proceeding

---

## Related Meta-Issue

- **#1372**: Master tracking issue for full docs audit + remediation
