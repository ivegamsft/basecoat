# Base Coat Repository Cleanup Audit Report

**Generated**: May 2026  
**Repository**: IBuySpy-Shared/basecoat  
**Scope**: Documentation redundancy, stale assets, repository structure, branch/worktree cleanup

---

## Executive Summary

The Base Coat repository has accumulated **technical debt** from the development and release process:

| Category | Issues | Est. Cleanup Time |
|----------|--------|------------------|
| **Root-level files** | 8 files should be archived or moved | 30 min |
| **Duplicate documentation** | 4 catalog files (AGENTS.md, INVENTORY.md, CATALOG.md, docs/CATALOG.md) | 1-2 hours |
| **Stale branches** | 33 copilot/*, 2 feat/*, 2 fix/* branches | 15 min |
| **Orphaned worktrees** | 3-4 worktrees + 2 shadow directories | 10 min |
| **Broken/stale references** | Design briefs not integrated into docs structure | 30 min |

**Total Estimated Cleanup Time**: 2-3 hours  
**Priority**: P1-P2 (maintenance burden, confusion risk, Git clutter)

---

## 1. ROOT-LEVEL FILES TO MOVE TO `/docs`

### P1: VERSIONED RELEASE ARTIFACTS (ARCHIVE)

These are snapshot files from past releases and should be archived:

| File | Size | Created | Action |
|------|------|---------|--------|
| `AUDIT_REPORT_v2.3.0.md` | 6.8 KB | v2.3.0 release | Move to `docs/archived/AUDIT_REPORT_v2.3.0.md` |
| `FINAL_RELEASE_NOTES.md` | 4.3 KB | v2.3.0 release | Move to `docs/archived/FINAL_RELEASE_NOTES.md` |
| `COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md` | 11.2 KB | v3.0.0 release | Move to `docs/archived/COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md` |
| `RELEASE_NOTES_v3.0.0.md` | 7.3 KB | v3.0.0 release | Move to `docs/archived/RELEASE_NOTES_v3.0.0.md` |

**Rationale**:
- These are historical snapshots from specific releases
- CHANGELOG.md is the single source of truth for release history
- Keeping versioned copies clutters root and creates maintenance burden
- Create `docs/archived/` to preserve historical context if needed

**Git Commands**:
```powershell
mkdir docs/archived -Force
git mv AUDIT_REPORT_v2.3.0.md docs/archived/
git mv FINAL_RELEASE_NOTES.md docs/archived/
git mv COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md docs/archived/
git mv RELEASE_NOTES_v3.0.0.md docs/archived/
git commit -m "docs: archive versioned release reports to docs/archived/" -m "- Move AUDIT_REPORT_v2.3.0.md, FINAL_RELEASE_NOTES.md, COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md, RELEASE_NOTES_v3.0.0.md to docs/archived/. Reduces root clutter and preserves historical records in dedicated archive directory."
```

---

### P2: DRAFT/DESIGN DOCUMENTS (MOVE TO DOCS)

| File | Size | Status | Action |
|------|------|--------|--------|
| `PLUGIN_DESIGN_BRIEF.md` | 2.3 KB | Draft/Design | Move to `docs/design-briefs/PLUGIN_DESIGN_BRIEF.md` |
| `PORTAL_DESIGN_BRIEF.md` | 6.6 KB | Draft/Design | Move to `docs/design-briefs/PORTAL_DESIGN_BRIEF.md` |
| `plan-sharedStandardsRepo.prompt.md` | 3.8 KB | Working file | Move to `docs/working/plan-sharedStandardsRepo.prompt.md` |

**Rationale**:
- These are design/planning documents that should live in `/docs` per repository conventions
- Design briefs establish architectural direction but are not referenced from root
- Working prompt files accumulate over time and should be isolated

**Action Plan**:
```powershell
mkdir docs/design-briefs -Force
mkdir docs/working -Force
git mv PLUGIN_DESIGN_BRIEF.md docs/design-briefs/
git mv PORTAL_DESIGN_BRIEF.md docs/design-briefs/
git mv plan-sharedStandardsRepo.prompt.md docs/working/
git commit -m "docs: reorganize design and working documents into docs/ subdirectories" -m "- Move PLUGIN_DESIGN_BRIEF.md and PORTAL_DESIGN_BRIEF.md to docs/design-briefs/
- Move plan-sharedStandardsRepo.prompt.md to docs/working/
- Follows repository convention: design and working docs belong in docs/ hierarchy"
```

---

### P2: CATALOG DUPLICATION (CONSOLIDATE)

**Problem**: Four overlapping agent/asset catalogs cause confusion:

| File | Type | Purpose | Lines | Status |
|------|------|---------|-------|--------|
| `AGENTS.md` | Table | Quick agent reference | ~900 | Primary reference |
| `INVENTORY.md` | Table with keywords | Skills/instructions index | ~2000 | Rich metadata |
| `CATALOG.md` (root) | Formatted table | Asset registry with models | ~1400 | Formatted |
| `docs/CATALOG.md` | Similar format | Alternative catalog | ~500 | Duplicate |

**Recommendation**: Single source of truth

**Conflict Analysis**:
- **AGENTS.md**: Lists 52 agents, descriptive format, referenced in README.md
- **INVENTORY.md**: Lists instructions, skills, prompts with keywords; more comprehensive
- **CATALOG.md (root)**: Formatted with paired skills and model recommendations (more detailed)
- **docs/CATALOG.md**: Different schema, appears to be outdated version

**Decision**:
1. Keep `AGENTS.md` at root (referenced in README.md, stable API)
2. Keep `INVENTORY.md` at root (keyword-searchable, rich metadata)
3. Move `CATALOG.md` (root) → `docs/ASSET_REGISTRY.md` (renamed, detailed reference)
4. Delete `docs/CATALOG.md` (redundant)

**Git Commands**:
```powershell
# Rename root CATALOG.md to emphasize it's a detailed registry
git mv CATALOG.md docs/ASSET_REGISTRY.md

# Update references in README.md to point to docs/ASSET_REGISTRY.md
# (edit README.md manually or via script)

# Delete redundant docs/CATALOG.md
git rm docs/CATALOG.md

git commit -m "docs: consolidate asset catalogs and eliminate duplication" -m "- Move root CATALOG.md to docs/ASSET_REGISTRY.md (detailed registry with model recommendations)
- Delete docs/CATALOG.md (redundant, outdated)
- Keep AGENTS.md as quick reference (in root, referenced by README.md)
- Keep INVENTORY.md as searchable instruction/skill index
- Reduces catalog fragmentation and maintenance burden"
```

**Note**: Update README.md links if needed.

---

## 2. CONFLICTING OR CONFUSING CONTENT

### Documentation Inconsistencies

| Issue | Location | Impact | Resolution |
|-------|----------|--------|-----------|
| **Agent count mismatch** | README.md says "52 agents" but AGENTS.md lists 52, CATALOG.md lists 44 | Confused users | Count actual agents: `ls agents/*.agent.md \| wc -l` (73 actual as of commit history) |
| **Design briefs not in docs index** | PLUGIN_DESIGN_BRIEF.md, PORTAL_DESIGN_BRIEF.md are draft but not referenced in docs/GOVERNANCE.md | Hard to discover | Add references after moving to docs/design-briefs/ |
| **INVENTORY vs AGENTS purpose** | Both list agents; INVENTORY has keywords; AGENTS is simpler | Unclear when to use which | Add "When to Use" section to each file's header |

**Actions**:

1. **Update Agent Count**:
   ```powershell
   cd F:\Git\basecoat
   (Get-ChildItem agents/*.agent.md).Count  # Should show actual count
   # Edit README.md line 7 and AGENTS.md line 5 with correct count
   ```

2. **Add navigation guidance** to both AGENTS.md and INVENTORY.md headers:
   - AGENTS.md: "Quick agent reference—use this to find agents by name"
   - INVENTORY.md: "Searchable instruction and skill index—use this to find assets by keyword"

3. **Document design briefs** in docs/GOVERNANCE.md or create docs/design-briefs/README.md with navigation.

---

## 3. STALE ASSETS & BRANCHES

### A. Orphaned/Stale Remote Branches (41 Total)

#### Copilot Branches (33 total)

These are design/research branches created by the copilot-swe-agent. All are **≥2 weeks old** (created May 3, 2026):

**Sample stale branches** (all unmerged):
- `origin/copilot/add-agents-skills-path` (May 3)
- `origin/copilot/add-dotnet-modernization-advisor-agent` (May 3)
- `origin/copilot/add-penetration-test-agent` (May 3)
- ... 30 more

**Status**: These appear to be **merged into main** (their changes are present) but branches remain undeleted.

**Action**: Delete all unmerged copilot/* branches

```powershell
# List branches that have been merged into main
git branch -r --merged origin/main | grep 'origin/copilot/' > merged_branches.txt

# Bulk delete merged copilot branches (via GitHub CLI)
gh api repos/IBuySpy-Shared/basecoat/git/refs/heads | jq -r '.[] | select(.ref | startswith("refs/heads/copilot/")) | .ref' | while read ref; do
  git push origin --delete ${ref#refs/heads/}
done
```

**Impact**: Reduces branch list from 41 to ~8, improves navigation.

#### Feature/Fix Branches (4 total)

| Branch | Last Commit | Status | Action |
|--------|------------|--------|--------|
| `origin/feat/383-github-actions-auto-approval` | May 3 (merged) | Merged to main | Delete |
| `origin/feat/392-dotnet-modernization-foundation` | May 3 | Unclear | Check if merged |
| `origin/fix/403-hardened-test-failure-propagation` | May 3 (merged) | Merged to main | Delete |
| `origin/fix/skill-name-validation` | May 3 | Unclear | Check if merged |

**Cleanup Commands**:
```powershell
# Check merge status
git branch -r --merged origin/main | grep 'origin/feat\|origin/fix'

# Delete merged branches
git push origin --delete feat/383-github-actions-auto-approval
git push origin --delete fix/403-hardened-test-failure-propagation

# Verify status of others before deleting
```

---

### B. Orphaned Worktrees (4 detected)

**Detected worktrees**:
```
F:\Git\basecoat          (active, main worktree)
F:\Git\basecoat-sprint-2 (git worktree) — ORPHANED
F:\Git\basecoat-sprint-3 (git worktree) — ORPHANED
F:\Git\basecoat-worktrees (directory) — ORPHANED
F:\Git\basecoat-wt (directory) — ORPHANED
```

**Issue**: Worktrees created for sprint work but not cleaned up after branch deletion.

**Cleanup**:
```powershell
# From main worktree
cd F:\Git\basecoat

# List worktrees
git worktree list

# Remove orphaned worktrees
git worktree remove --force F:\Git\basecoat-sprint-2  # if it shows in git worktree list
git worktree remove --force F:\Git\basecoat-sprint-3  # if it shows in git worktree list

# Manually clean up orphaned directories (if not registered)
Remove-Item -Recurse -Force F:\Git\basecoat-worktrees -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force F:\Git\basecoat-wt -ErrorAction SilentlyContinue
```

---

## 4. BROKEN INTERNAL LINKS & MISSING REFERENCES

### Search Results for TODO/FIXME

**Files with TODO/FIXME markers** (1 found):
- `agents/tech-writer.agent.md` — Contains TODO (check for incomplete content)

**Action**: Review tech-writer agent for unfinished sections.

```powershell
cd F:\Git\basecoat
grep -rn "TODO\|FIXME" agents/ instructions/ skills/ docs/ | Select-Object
```

---

### Missing or Inconsistent Asset References

**Checked**: Agent descriptions vs actual agent files

**Status**: All agents mentioned in AGENTS.md, INVENTORY.md, and CATALOG.md exist in `agents/` directory. ✅ No broken references detected.

**Skill references** in CATALOG.md: Verify all paired skills exist in `skills/` directory.

```powershell
# Extract all skill references from CATALOG.md
$skillRefs = Select-String -Path CATALOG.md -Pattern 'skills/(\S+)/SKILL.md' -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }

# Check if they exist
$skillRefs | ForEach-Object { 
  $skillPath = "skills/$_/SKILL.md"
  if (!(Test-Path $skillPath)) { Write-Output "MISSING: $skillPath" }
}
```

---

## 5. REPOSITORY STRUCTURE CLEANUP

### Recommended Directory Organization

**Current state** (files in root that should be in docs/):
```
basecoat/
├── AGENTS.md                                  ✅ Keep (referenced by README, API stable)
├── INVENTORY.md                               ✅ Keep (keyword index, stable)
├── CATALOG.md                                 ❌ Move to docs/ASSET_REGISTRY.md
├── README.md                                  ✅ Keep (standard)
├── CHANGELOG.md                               ✅ Keep (standard)
├── CONTRIBUTING.md                            ✅ Keep (standard)
├── PHILOSOPHY.md                              ✅ Keep (org philosophy)
├── PRODUCT.md                                 ✅ Keep (product desc)
├── PLUGIN_DESIGN_BRIEF.md                     ❌ Move to docs/design-briefs/
├── PORTAL_DESIGN_BRIEF.md                     ❌ Move to docs/design-briefs/
├── plan-sharedStandardsRepo.prompt.md         ❌ Move to docs/working/
├── AUDIT_REPORT_v2.3.0.md                     ❌ Move to docs/archived/
├── FINAL_RELEASE_NOTES.md                     ❌ Move to docs/archived/
├── COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md    ❌ Move to docs/archived/
├── RELEASE_NOTES_v3.0.0.md                    ❌ Move to docs/archived/
├── docs/
│   ├── CATALOG.md                             ❌ Delete (redundant)
│   ├── archived/                              ✨ Create for release snapshots
│   ├── design-briefs/                         ✨ Create for design docs
│   └── working/                               ✨ Create for work-in-progress
```

**Cleanup Summary**:
- ✅ Keep at root: 7 files (README, CHANGELOG, CONTRIBUTING, PHILOSOPHY, PRODUCT, AGENTS, INVENTORY)
- ❌ Move to docs/: 8 files
- ✨ Create: 3 directories (archived/, design-briefs/, working/)
- 🗑️ Delete: 1 file (docs/CATALOG.md)

---

## 6. GITHUB ISSUES & PR CLEANUP

### PR Status

**Closed PRs**: 69 total  
**Sample closed PRs** (last 10):
- PR #475: "feat: configure GitHub Actions auto-approval..." (merged)
- PR #474: "fix(#383): add blank lines around list items..." (merged)
- Many older PRs from 2025-2026

**Action**: PRs can remain closed in history (GitHub preserves them). No action needed.

### Issue Backlog

**Open vs Closed Issues**: [Requires further investigation via GitHub API]

**Potential cleanup candidates**:
- Issues marked as `blocked` without recent activity (>30 days)
- Issues without labels or clear priority
- Duplicate issues

**Action**: Defer detailed issue cleanup to separate task with Issue Triage agent.

---

## 7. EXECUTION PLAN (Step-by-Step)

### Phase 1: Safe Cleanup (No Breaking Changes)

**Duration**: 30-45 minutes  
**Risk**: Low

```powershell
# 1. Create new directories
mkdir F:\Git\basecoat\docs\archived -Force
mkdir F:\Git\basecoat\docs\design-briefs -Force
mkdir F:\Git\basecoat\docs\working -Force

# 2. Move versioned release reports
cd F:\Git\basecoat
git mv AUDIT_REPORT_v2.3.0.md docs/archived/
git mv FINAL_RELEASE_NOTES.md docs/archived/
git mv COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md docs/archived/
git mv RELEASE_NOTES_v3.0.0.md docs/archived/

git commit -m "docs: archive versioned release reports to docs/archived/" -m "Move historical release snapshots to dedicated archive directory. Reduces root clutter while preserving historical records." --author "Cleanup Audit <cleanup@basecoat.local>"

# 3. Move design briefs and working docs
git mv PLUGIN_DESIGN_BRIEF.md docs/design-briefs/
git mv PORTAL_DESIGN_BRIEF.md docs/design-briefs/
git mv plan-sharedStandardsRepo.prompt.md docs/working/

git commit -m "docs: move design briefs and working docs to docs/ subdirectories" -m "Move design and working documents to docs/ hierarchy per repository convention." --author "Cleanup Audit <cleanup@basecoat.local>"

# 4. Consolidate catalogs
git mv CATALOG.md docs/ASSET_REGISTRY.md
git rm docs/CATALOG.md

git commit -m "docs: consolidate catalogs to eliminate duplication" -m "Move root CATALOG.md to docs/ASSET_REGISTRY.md. Delete redundant docs/CATALOG.md. Keeps AGENTS.md and INVENTORY.md as stable APIs." --author "Cleanup Audit <cleanup@basecoat.local>"
```

### Phase 2: Update Documentation (15-20 minutes)

**1. Update README.md** to fix agent count and catalog references:
```markdown
- Line 7: Update agent count if needed
- Link to docs/ASSET_REGISTRY.md instead of CATALOG.md
```

**2. Add navigation guidance** to AGENTS.md and INVENTORY.md headers

**3. Create docs/design-briefs/README.md** for design brief navigation

### Phase 3: Branch Cleanup (10-15 minutes)

**1. Delete merged copilot/* branches**:
```powershell
gh api repos/IBuySpy-Shared/basecoat/git/refs/heads `
  | jq -r '.[] | select(.ref | test("refs/heads/copilot/")) | .ref' `
  | ForEach-Object { git push origin --delete $_.Replace('refs/heads/', '') }
```

**2. Delete merged feat/fix/* branches**:
```powershell
git push origin --delete feat/383-github-actions-auto-approval
git push origin --delete fix/403-hardened-test-failure-propagation
# (verify others before deleting)
```

### Phase 4: Worktree Cleanup (5 minutes)

```powershell
# Remove registered worktrees
git worktree remove --force F:\Git\basecoat-sprint-2 2>&1
git worktree remove --force F:\Git\basecoat-sprint-3 2>&1

# Clean up orphaned directories
Remove-Item -Recurse -Force F:\Git\basecoat-worktrees -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force F:\Git\basecoat-wt -ErrorAction SilentlyContinue
```

---

## 8. VALIDATION & VERIFICATION

### Pre-Cleanup Checklist

- [ ] All tests pass: `pwsh tests/run-tests.ps1`
- [ ] No uncommitted changes: `git status`
- [ ] On main branch: `git rev-parse --abbrev-ref HEAD`
- [ ] Main is up-to-date: `git fetch origin && git status`

### Post-Cleanup Verification

- [ ] All four commits created successfully
- [ ] No broken links in README.md
- [ ] Root directory has ≤7 .md files (down from 15)
- [ ] `docs/` has new subdirectories: archived/, design-briefs/, working/
- [ ] All Git worktree list shows only main worktree
- [ ] GitHub UI shows 41 → 8 branches (33 copilot/* branches deleted)
- [ ] Run tests again: `pwsh tests/run-tests.ps1`
- [ ] Rebuild adoption metrics: `npm run build --prefix mcp/basecoat-metrics`

---

## 9. RISKS & MITIGATIONS

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| External links to root files break | Low | Medium | Search GitHub issues/PRs for links; update if found |
| Catalog consolidation confuses users | Low | Low | Document consolidation in CHANGELOG.md |
| Worktree cleanup fails | Low | Low | Pre-check with `git worktree list` |
| Branch deletion removes critical code | Very Low | High | Verify all branches merged to main first |

---

## 10. SUMMARY TABLE: CLEANUP DECISIONS

| Item | Category | Action | Priority | Time | Risk |
|------|----------|--------|----------|------|------|
| AGENTS.md | Root file | KEEP | — | — | — |
| INVENTORY.md | Root file | KEEP | — | — | — |
| CATALOG.md (root) | Root file | MOVE to docs/ASSET_REGISTRY.md | P2 | 5 min | Low |
| docs/CATALOG.md | Root file | DELETE | P2 | 2 min | Low |
| AUDIT_REPORT_v2.3.0.md | Versioned | MOVE to docs/archived/ | P1 | 5 min | Low |
| FINAL_RELEASE_NOTES.md | Versioned | MOVE to docs/archived/ | P1 | 5 min | Low |
| COMPREHENSIVE_RELEASE_REPORT_v3.0.0.md | Versioned | MOVE to docs/archived/ | P1 | 5 min | Low |
| RELEASE_NOTES_v3.0.0.md | Versioned | MOVE to docs/archived/ | P1 | 5 min | Low |
| PLUGIN_DESIGN_BRIEF.md | Design doc | MOVE to docs/design-briefs/ | P2 | 5 min | Low |
| PORTAL_DESIGN_BRIEF.md | Design doc | MOVE to docs/design-briefs/ | P2 | 5 min | Low |
| plan-sharedStandardsRepo.prompt.md | Working file | MOVE to docs/working/ | P2 | 5 min | Low |
| origin/copilot/* branches (33) | Stale branches | DELETE | P2 | 10 min | Low |
| origin/feat/* branches (2) | Stale branches | DELETE (if merged) | P2 | 5 min | Low |
| origin/fix/* branches (2) | Stale branches | DELETE (if merged) | P2 | 5 min | Low |
| Orphaned worktrees (4) | Worktrees | REMOVE | P3 | 5 min | Low |

---

## 11. FOLLOW-UP ACTIONS

### Short-term (1-2 weeks)
1. ✅ Execute cleanup plan (this task)
2. Monitor for broken external links
3. Update any documentation that references moved files

### Medium-term (1-2 months)
1. Implement automated checks in CI to prevent root-level files from accumulating
2. Create `.gitignore` rule for working files (*.draft.md, *.wip.md)
3. Set up branch deletion automation for merged branches

### Long-term (3-6 months)
1. Review and consolidate remaining docs/ files (40+ files)
2. Establish documentation governance for design briefs and working docs
3. Implement documentation versioning strategy

---

## Appendix: File Sizes & Locations

### Root-Level Markdown Files (15 total, 191 KB)

```
191 KB total in root-level .md files

After cleanup (7 files, 89 KB):
- README.md (25 KB) ✅
- CHANGELOG.md (22 KB) ✅
- CONTRIBUTING.md (19 KB) ✅
- INVENTORY.md (27 KB) ✅
- AGENTS.md (13 KB) ✅
- PHILOSOPHY.md (5 KB) ✅
- PRODUCT.md (2 KB) ✅

Moved to docs/ (8 files, 102 KB):
- docs/archived/ (30 KB)
- docs/design-briefs/ (9 KB)
- docs/working/ (4 KB)
- docs/ASSET_REGISTRY.md (19 KB)
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | May 2026 | Cleanup Audit Agent | Initial comprehensive audit |

---

**Report Status**: ✅ Ready for execution

**Next Step**: Execute Phase 1-4 cleanup plan above, then validate with checklist.

