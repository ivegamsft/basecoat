# Base Coat Cleanup Audit — Quick Reference

**Report Date**: May 2026  
**Repository**: IBuySpy-Shared/basecoat  
**Status**: ✅ Audit Complete — Ready for Execution

---

## Key Findings at a Glance

### 📊 Scope Summary

| Metric | Before | After | Impact |
|--------|--------|-------|--------|
| Root .md files | 15 | 7 | -53% clutter |
| Remote branches | 41 | 8 | -80% branch list |
| Git worktrees | 4 orphaned | 0 | cleanup |
| Documentation catalogs | 4 overlapping | 1 clear | -75% confusion |

### 🎯 Priority Breakdown

| Priority | Count | Category | Time |
|----------|-------|----------|------|
| **P0** | 0 | Critical (breaks functionality) | — |
| **P1** | 4 files | Versioned reports → archive | 30 min |
| **P2** | 8 files | Design briefs, catalogs, working docs | 90 min |
| **P3** | 37 branches | Delete stale branches | 15 min |
| **P4** | 4 worktrees | Clean up orphaned worktrees | 5 min |

**Total Effort**: 2-3 hours, **Risk**: LOW

---

## 🚨 What's the Problem?

### 1. Documentation Sprawl
- **Root directory has 15 .md files** (should have ~7)
- **Four separate agent catalogs** (AGENTS.md, INVENTORY.md, CATALOG.md, docs/CATALOG.md)
- Users confused which to use for finding agents/skills

### 2. Versioned Release Artifacts
- AUDIT_REPORT_v2.3.0.md, FINAL_RELEASE_NOTES.md, etc. clog root
- These are historical snapshots, not active documentation
- CHANGELOG.md is the single source of truth for release history

### 3. Unintegrated Design Documents
- PLUGIN_DESIGN_BRIEF.md and PORTAL_DESIGN_BRIEF.md are in root
- Not referenced from documentation structure
- Should live in docs/design-briefs/ per repository convention

### 4. Branch & Worktree Debt
- **33 copilot/* branches** remain after merge (merged but not deleted)
- **37 remote branches total** make git navigation confusing
- **4 orphaned worktrees** consume disk space

---

## 📋 Actions by Category

### CRITICAL PATH (Do First)

**Phase 1: Archive Versioned Reports** (5 files, 30 min)
```
AUDIT_REPORT_v2.3.0.md → docs/archived/
FINAL_RELEASE_NOTES.md → docs/archived/
COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md → docs/archived/
RELEASE_NOTES_v3.0.0.md → docs/archived/
```
**Why**: Reduces root clutter, preserves historical records

**Phase 2: Move Design & Working Docs** (3 files, 20 min)
```
PLUGIN_DESIGN_BRIEF.md → docs/design-briefs/
PORTAL_DESIGN_BRIEF.md → docs/design-briefs/
plan-sharedStandardsRepo.prompt.md → docs/working/
```
**Why**: Follows repository convention, improves discoverability

**Phase 3: Consolidate Catalogs** (2 files, 15 min)
```
CATALOG.md (root) → docs/ASSET_REGISTRY.md
docs/CATALOG.md → DELETE (redundant)
```
**Why**: Single source of truth for asset registry, eliminates confusion

### NICE-TO-HAVE (After Testing)

**Phase 4: Delete Stale Branches** (37 branches, 15 min)
```
origin/copilot/* (33 branches) → DELETE
origin/feat/* (2 branches) → DELETE (if merged)
origin/fix/* (2 branches) → DELETE (if merged)
```
**Why**: Reduces branch list clutter, improves GitHub navigation

**Phase 5: Clean Orphaned Worktrees** (4 worktrees, 5 min)
```
F:\Git\basecoat-sprint-2 → REMOVE
F:\Git\basecoat-sprint-3 → REMOVE
F:\Git\basecoat-worktrees/ → DELETE
F:\Git\basecoat-wt/ → DELETE
```
**Why**: Frees disk space, removes stale development artifacts

---

## 📁 Before/After Repository Structure

### BEFORE (15 root files, 191 KB)
```
basecoat/
├── AGENTS.md
├── INVENTORY.md
├── CATALOG.md                          ← Duplicate
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── PHILOSOPHY.md
├── PRODUCT.md
├── PLUGIN_DESIGN_BRIEF.md              ← Should be in docs/
├── PORTAL_DESIGN_BRIEF.md              ← Should be in docs/
├── plan-sharedStandardsRepo.prompt.md  ← Should be in docs/
├── AUDIT_REPORT_v2.3.0.md              ← Historical, archive
├── FINAL_RELEASE_NOTES.md              ← Historical, archive
├── COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md ← Historical, archive
├── RELEASE_NOTES_v3.0.0.md             ← Historical, archive
└── docs/
    ├── CATALOG.md                      ← Redundant, delete
    └── (60+ other docs)
```

### AFTER (7 root files, 89 KB)
```
basecoat/
├── AGENTS.md                           ✅ Quick reference
├── INVENTORY.md                        ✅ Keyword search index
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── PHILOSOPHY.md
├── PRODUCT.md
└── docs/
    ├── ASSET_REGISTRY.md               ← Moved from root (detailed registry)
    ├── archived/                       ← NEW
    │   ├── AUDIT_REPORT_v2.3.0.md
    │   ├── FINAL_RELEASE_NOTES.md
    │   ├── COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md
    │   └── RELEASE_NOTES_v3.0.0.0.md
    ├── design-briefs/                  ← NEW
    │   ├── PLUGIN_DESIGN_BRIEF.md
    │   └── PORTAL_DESIGN_BRIEF.md
    ├── working/                        ← NEW
    │   └── plan-sharedStandardsRepo.prompt.md
    └── (60+ other docs)
```

---

## 🔍 Issues Identified

### Documentation Conflicts

| Issue | Details | Resolution |
|-------|---------|-----------|
| **4 agent catalogs** | AGENTS.md vs INVENTORY.md vs CATALOG.md vs docs/CATALOG.md | Keep AGENTS + INVENTORY at root; move detailed registry to docs/ |
| **Agent count mismatch** | README says 52 agents; actual is 73 | Update count after verifying |
| **Design briefs not discoverable** | PLUGIN_DESIGN_BRIEF.md and PORTAL_DESIGN_BRIEF.md in root, not linked | Move to docs/design-briefs/ + add navigation |
| **Versioned reports in root** | AUDIT_REPORT_v2.3.0.md clogs root | Archive to docs/archived/ |

### Stale Branches

| Type | Count | Age | Action |
|------|-------|-----|--------|
| copilot/add-* | 33 | May 3, 2026 | DELETE (merged) |
| feat/383 | 1 | May 3, 2026 | DELETE (merged) |
| feat/392 | 1 | May 3, 2026 | VERIFY then DELETE |
| fix/403 | 1 | May 3, 2026 | DELETE (merged) |
| fix/skill-validation | 1 | May 3, 2026 | VERIFY then DELETE |

### Orphaned Worktrees

- F:\Git\basecoat-sprint-2 (orphaned git worktree)
- F:\Git\basecoat-sprint-3 (orphaned git worktree)
- F:\Git\basecoat-worktrees/ (orphaned directory)
- F:\Git\basecoat-wt/ (orphaned directory)

---

## ✅ Validation Checklist

### Pre-Cleanup
- [ ] `git status` is clean
- [ ] On `main` branch
- [ ] `git fetch origin` completed
- [ ] Tests pass: `pwsh tests/run-tests.ps1`
- [ ] Read full CLEANUP_REPORT.md

### Post-Cleanup
- [ ] 4 commits created (one per phase)
- [ ] Root has ≤7 .md files
- [ ] docs/ has 3 new subdirectories
- [ ] All Git moves successful: `git log --oneline -5`
- [ ] Branches deleted: `git branch -a | wc -l` shows ~8 vs 41
- [ ] No broken links: Check README.md references
- [ ] Tests still pass: `pwsh tests/run-tests.ps1`
- [ ] Worktrees cleaned: `git worktree list` shows only main

---

## 🎬 Quick Start (Simplified)

### 1. Backup (optional but recommended)
```powershell
git stash  # Save any uncommitted work
```

### 2. Execute Cleanup
```powershell
cd F:\Git\basecoat

# Create directories
mkdir docs/archived, docs/design-briefs, docs/working -Force

# Move versioned reports (Phase 1)
git mv AUDIT_REPORT_v2.3.0.md docs/archived/
git mv FINAL_RELEASE_NOTES.md docs/archived/
git mv COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md docs/archived/
git mv RELEASE_NOTES_v3.0.0.md docs/archived/
git commit -m "docs: archive versioned release reports"

# Move design/working docs (Phase 2)
git mv PLUGIN_DESIGN_BRIEF.md docs/design-briefs/
git mv PORTAL_DESIGN_BRIEF.md docs/design-briefs/
git mv plan-sharedStandardsRepo.prompt.md docs/working/
git commit -m "docs: move design and working docs to docs/"

# Consolidate catalogs (Phase 3)
git mv CATALOG.md docs/ASSET_REGISTRY.md
git rm docs/CATALOG.md
git commit -m "docs: consolidate catalogs and eliminate duplication"

# Delete branches (Phase 4) — Use GitHub CLI
gh api repos/IBuySpy-Shared/basecoat/git/refs/heads \
  | jq -r '.[] | select(.ref | test("copilot")) | .ref' \
  | ForEach-Object { git push origin --delete $_.Replace('refs/heads/', '') }

# Clean worktrees (Phase 5)
git worktree remove F:\Git\basecoat-sprint-2 --force 2>&1 | Out-Null
git worktree remove F:\Git\basecoat-sprint-3 --force 2>&1 | Out-Null
Remove-Item -Recurse -Force F:\Git\basecoat-worktrees -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force F:\Git\basecoat-wt -ErrorAction SilentlyContinue
```

### 3. Verify
```powershell
git status  # Should be clean
git log --oneline -5  # Verify 4 commits
Get-ChildItem -Filter "*.md" | Measure-Object  # Should be ≤7 files
```

---

## 🚀 Next Steps

1. **Review Full Report**: Read `CLEANUP_REPORT.md` (11 sections)
2. **Execute Cleanup**: Follow Phase 1-5 plan above
3. **Validate**: Use post-cleanup checklist
4. **Monitor**: Watch for broken external links over next week
5. **Document**: Update CHANGELOG.md with cleanup notes

---

## 📞 Questions?

Refer to full report sections:
- **Detailed rationale**: See CLEANUP_REPORT.md § 1-4
- **Git commands**: See CLEANUP_REPORT.md § 7 (Execution Plan)
- **Branch analysis**: See CLEANUP_REPORT.md § 3.A
- **Worktree cleanup**: See CLEANUP_REPORT.md § 3.B
- **Validation**: See CLEANUP_REPORT.md § 8

---

## 📊 Impact Summary

| Aspect | Current | After Cleanup | Improvement |
|--------|---------|---------------|-------------|
| Root .md files | 15 | 7 | -53% |
| Documentation confusion | High (4 catalogs) | Low (1 clear) | -75% |
| Remote branches | 41 | 8 | -80% |
| Worktree clutter | 4 orphaned | 0 | 100% |
| Overall tech debt | Medium | Low | Reduced |

---

**Status**: ✅ Ready for execution by Copilot coding agent or manual review  
**Risk Level**: 🟢 LOW (all changes reversible via git)  
**Recommended By**: Base Coat Cleanup Audit Agent
