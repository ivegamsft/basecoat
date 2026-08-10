<!-- markdownlint-disable MD031 MD032 MD036 MD040 MD041 -->

## Memory Workflow Distribution & Templatization Strategy

### Executive Summary

This design document addresses issue #1304: assessing distribution and templatization strategy for BaseCoat's memory workflows. The document proposes a **Phase-based approach aligned with the agentic workflow distribution model (#1305)**, marking memory workflows as **Internal-only in Phase 1** with deferred templatization to Phase 3 if consumer demand emerges.

Memory workflows are **operational/infrastructure workflows** distinct from consumer-facing agentic workflows. They support BaseCoat's internal learning repository (`basecoat-memory`) and adoption metrics infrastructure. Consumer value is lower than agentic workflows, and dependency on BaseCoat-specific infrastructure makes them less portable.

---

## Current State Assessment

### Memory Workflows Inventory

| Workflow | Purpose | Trigger | Consumer-facing | Internal Dependency |
|----------|---------|---------|-----------------|---------------------|
| **memory-audit.yml** | Quarterly audit of memory file freshness & validity | Scheduled + manual | ❌ | {org}/basecoat-memory |
| **memory-contribute.yml** | Dispatch workflow for storing learned facts in memory repo | Manual (programmatic) | ❌ | {org}/basecoat-memory |
| **memory-sweep.yml** | Weekly enterprise memory sweep for learning signals | Scheduled + manual | ⚠️ Partial | {org}/basecoat-memory + topic scanning |
| **adoption-metrics.yml** | Collect & publish adoption metrics dashboard | Scheduled + workflow_run | ❌ | basecoat-metrics MCP + dashboard infra |
| **fork-import.yml** | Import issues from development forks | Manual | ❌ | Fork maintenance (ivegamsft/basecoat) |

### Design Questions from #1304

1. **Should memory-audit.yml be consumer-facing?**
   - **Answer**: No. Consumers do not need to audit BaseCoat's memory repository. If consumers build their own memory repos (Phase 3), they would need a similar pattern, but audit logic is org-specific.

2. **Can memory-contribute.yml be parameterized for consumer memory repos?**
   - **Answer**: Partially. The workflow is already highly parameterized (base64-encoded JSON input). However, it's designed as an internal dispatcher (called by other systems). Consumer adoption would require new patterns (webhooks, CI/CD integration).

3. **What's the consumer use case for org learning repositories?**
   - **Answer**: Moderate. Enterprises might build their own org learning repos similar to basecoat-memory (e.g., "company-learnings"). Phase 3 could provide templates, but demand is uncertain. Current focus should remain on agentic workflows (#1305).

4. **Can fork-import.yml be generalized for consumer fork workflows?**
   - **Answer**: Partially. The workflow is specific to BaseCoat's dual-repo model (ivegamsft/basecoat fork + ivegamsft/basecoat main). Generalization would require significant parameterization and is low-value for consumers.

5. **Can adoption-metrics.yml work with consumer custom metrics?**
   - **Answer**: No. The workflow is tightly coupled to BaseCoat's metrics collection infrastructure (Python scripts, MCP server, dashboard design). Consumer metrics would need entirely different collection logic.

6. **What secrets/tokens would consumers need?**
   - **Answer**: If templatized in Phase 3:
     - `MEMORY_REPO_TOKEN`: Fine-grained PAT for consumer memory repo (Contents: RW, PRs: RW)
     - `GITHUB_TOKEN`: org-scoped read access for sweeping enlisted repos

---

## Design Decisions

### Decision 1: Phase-based Distribution Strategy

**Recommendation: Phase 1 = Internal-only; Phase 3 = Conditional Templatization**

#### Phase 1 (Immediate): Internal-only Mark

**Action**: Document memory workflows as "Internal operational — not for distribution"
- Add explicit metadata/tags to each workflow
- Update CONTRIBUTING.md with internal workflow guidelines
- Mark in workflow inventory/catalog

**Rationale**:
- Memory workflows are infrastructure, not consumer-facing agents
- High dependency on BaseCoat-specific repos (basecoat-memory) and infrastructure
- Templatization effort >> consumer value in Phase 1
- Phase 1 prioritizes agentic workflow distribution (#1305)

**Workflow Status for Phase 1**:
- `memory-audit.yml`: ❌ Internal-only (skip templatization)
- `memory-contribute.yml`: ❌ Internal-only (skip templatization)
- `memory-sweep.yml`: ⚠️ Partially templatizable (revisit Phase 2)
- `adoption-metrics.yml`: ❌ Internal-only (skip templatization)
- `fork-import.yml`: ❌ Internal-only (skip templatization)

---

### Decision 2: Memory-sweep.yml — Deferred Templatization

**Recommendation: Phase 2 pre-planning; Phase 3 conditional templatization**

`memory-sweep.yml` is the most generalizable of the memory workflows because it implements a common pattern: **scanning org repos for signals and promoting curated learnings to a centralized repository**.

#### Why Defer to Phase 3?

1. **Dependency on repo enlistment pattern**: Requires `basecoat-enabled` topic (org-specific)
2. **Signal extraction logic is BaseCoat-specific**: Scans for PR reviews, commit messages, CHANGELOGs (would need customization)
3. **Output format is BaseCoat-specific**: Markdown structure, memory-sweep candidates format
4. **Consumer demand uncertain**: No current requests; would only be useful for large enterprises with learning programs

#### Phase 2 Pre-Planning (Optional)

If early customer feedback suggests value, Phase 2 could:
- Refactor signal extraction into pluggable modules
- Parameterize repo topic and output format
- Document custom signal patterns

#### Phase 3: Templatization Path (If Demanded)

If Phase 2 shows customer demand, Phase 3 would deliver:

```text
@basecoat/memory-workflows (npm package)
├── templates/
│   ├── memory-sweep.yml           # Parameterized template
│   ├── memory-audit.yml           # Optional: audit template
│   └── memory-contribute.yml      # Optional: contribute workflow
├── lib/
│   ├── signal-extractors/         # Pluggable signal modules
│   │   ├── changelog-signals.ts
│   │   ├── pr-review-signals.ts
│   │   ├── commit-message-signals.ts
│   │   └── custom.ts
│   ├── memory-repo-setup.ts       # Initialize consumer memory repo
│   └── repo-enlistment.ts         # Topic scanning logic
├── docs/
│   ├── MEMORY_SWEEP_SETUP.md
│   ├── CUSTOM_SIGNALS.md
│   └── MEMORY_REPO_ARCHITECTURE.md
└── examples/
    ├── basic-sweep/               # No customization
    ├── with-custom-signals/       # Custom signal types
    └── multi-org-sweep/           # Multiple orgs
```

**Consumer Setup (Phase 3, if implemented)**:

```bash
# Initialize memory repo
npx @basecoat/memory-workflows init-memory-repo \
  --org acme \
  --repo acme/company-learnings

# Generate parameterized sweep workflow
npx @basecoat/memory-workflows generate-sweep \
  --source-topic "acme-learning-enabled" \
  --signal-types "changelog,pr-reviews,commits" \
  --output-dir ".github/workflows"

# Deploy
git add .github/workflows/memory-sweep.yml
git commit -m "feat: add org learning sweep"
git push
```

---

### Decision 3: Adoption Metrics — Not Distributable

**Recommendation: Internal-only, no templatization planned**

`adoption-metrics.yml` is **highly specific to BaseCoat's infrastructure** and not suitable for consumer distribution:

#### Why Not Distributable?

1. **Tightly coupled to BaseCoat metrics infrastructure**
   - MCP server: `basecoat-metrics` (in-repo, BaseCoat-specific)
   - Python collection script: `scripts/metrics/collect-metrics.py` (BaseCoat metric definitions)
   - Dashboard: GitHub Pages + MkDocs (BaseCoat-specific structure)

2. **Consumer metrics would need entirely different logic**
   - Consumer metrics use different KPIs (agent adoption, skill usage, custom benchmarks)
   - Metrics collection backend would be different (Datadog, CloudWatch, etc.)
   - Dashboard would need custom visualization

3. **No consumer demand signal**: Not mentioned in feature requests or roadmap

#### Alternative for Consumers

If consumers want adoption metrics for their agents:
- Document best practices for custom metrics collection (separate initiative, not here)
- Point to external tools (Datadog, New Relic, CloudWatch)
- Provide examples of Agent health dashboards (Phase 3, if demand emerges)

---

### Decision 4: Fork-Import & Memory-Audit — Specific to BaseCoat Workflow

**Recommendation: Internal-only, no templatization**

Both workflows are part of BaseCoat's internal development workflow and not suitable for consumer distribution:

#### fork-import.yml (Internal-only)

- **Purpose**: Maintain dual-repo strategy (ivegamsft/basecoat fork + ivegamsft/basecoat main)
- **Consumer Value**: None. Consumers do not maintain development forks of BaseCoat.
- **Not Templatizable**: Logic is specific to BaseCoat's fork maintenance model.

#### memory-audit.yml (Internal-only)

- **Purpose**: Quarterly validation and stale detection for memory repository
- **Consumer Value**: If they build own memory repos (Phase 3), they may want similar validation.
- **Not Templatizable Yet**: Audit logic is highly BaseCoat-specific (memory file schema, freshness thresholds).
- **Future**: Could become part of `@basecoat/memory-workflows` package if Phase 3 memory-sweep templatization is approved.

---

### Decision 5: Documentation & Metadata Tagging

**Recommendation: Add "Internal-only" metadata to all memory workflows**

#### Implementation

Add frontmatter tag to each workflow (YAML header):

```yaml
name: "BaseCoat - Memory Audit"
# ... existing config ...

# Distribution metadata
distribution:
  status: "internal-only"  # Options: internal-only, distributable, phase-2-candidate, phase-3-candidate
  reason: "BaseCoat-specific memory repository infrastructure"
  related_issue: "#1304"
  sdk_package: null        # Would reference @basecoat/memory-workflows in Phase 3
  last_reviewed: "2024-01"
```

#### Update Documentation

1. **CONTRIBUTING.md**: Add section "Internal Operational Workflows"
   ```markdown
   ### Internal Operational Workflows
   
   These workflows are not intended for distribution or consumer use:
   - memory-audit.yml
   - memory-contribute.yml
   - adoption-metrics.yml
   - fork-import.yml
   
   Rationale: Tightly coupled to BaseCoat infrastructure. See docs/design/memory-workflow-distribution.md
   ```

2. **docs/design/memory-workflow-distribution.md**: This document (reference implementation)

3. **docs/workflows/WORKFLOWS.md** (if exists): Mark with "Internal" tag

---

## Impacts on Downstream Work

### Impact on Issue #1305: Agentic Workflow Distribution

**Decision 1305**: Hybrid distribution model (Source .md + compiled .lock.yml + Consumer Agent SDK)

**Alignment with #1304**:
- Memory workflows are NOT included in Consumer Agent SDK (Phase 1)
- Memory workflows have no consumer-facing agent workflows
- Memory workflows marked as "Internal-only" in workflow inventory

**Action**: Update agentic-workflow-distribution.md to clarify that Decision 5 marks memory workflows as out-of-scope for Phase 1 distribution.

### Impact on Issue #1303: CI/CD Templatization

**Decision 1303**: Integrate CI/CD validation patterns into Consumer Agent SDK

**Alignment with #1304**:
- CI/CD templatization is separate from memory workflow templatization
- Memory workflows do not provide CI/CD patterns useful for consumers
- No interaction between #1303 and #1304

**Action**: None. #1303 and #1304 are independent.

### Impact on Consumer Agent SDK

**Consumer Agent SDK (@basecoat/agent-sdk)**: Does NOT include memory workflow templates in Phase 1
- Memory workflows are marked as "Internal-only"
- Phase 1 SDK focuses on agentic workflows (code review, triage, etc.)
- Phase 3 may add optional memory workflow templates if demand emerges

**Action**: SDK documentation should explicitly state "Memory workflows are internal-only and not included in this release."

### Impact on Workflow Installer/Docs

**Phase 1**: No changes needed. Memory workflows remain in `.github/workflows/` and are not published.

**Phase 2**: Optional pre-planning for memory-sweep.yml refactoring (if Phase 3 looks favorable).

**Phase 3**: If templatization is approved, new package `@basecoat/memory-workflows` would be created alongside expanded `@basecoat/agent-sdk`.

---

## Implementation Roadmap

### Phase 1 Immediate Tasks (This Sprint)

1. ✅ Complete design document (this issue)
2. Add distribution metadata tags to all 5 memory workflows
3. Update CONTRIBUTING.md with "Internal Operational Workflows" section
4. Update agentic-workflow-distribution.md (Decision 5) to align on memory workflows scope
5. Post comment on #1304 summarizing Phase 1 decision

**Effort**: 30 minutes (documentation + metadata tags)

### Phase 2 Tasks (Q2 2024, pending demand signal)

- *Optional*: Pre-plan memory-sweep.yml refactoring for Phase 3 (if customer feedback suggests value)
- Monitor for consumer requests for org learning repositories
- No concrete deliverables unless demand emerges

### Phase 3 Tasks (Q3-Q4 2024, if approved)

- *Optional*: Create `@basecoat/memory-workflows` npm package
- Templatize memory-sweep.yml with pluggable signal extractors
- Publish as separate SDK release
- Document custom signal patterns and consumer setup

---

## Open Questions & Risks

### Question 1: Should consumers ever build memory repositories?

**Issue**: Is there genuine use case for enterprise learning repositories outside BaseCoat?

**Risk**: If yes, Phase 3 templatization becomes higher priority; if no, memory workflows remain internal forever.

**Mitigation**:
- Monitor customer feature requests during Phase 1/2
- Soft-signal: ask early adopters if they want org learning repos
- Phase 2 re-assessment: if >2 customers request, elevate to Phase 3 planning

### Question 2: Who maintains memory workflows if templatized?

**Issue**: If Phase 3 delivers `@basecoat/memory-workflows` package, who supports consumers using them?

**Risk**: Support burden could be high; memory workflows are complex (token strategies, branch logic, repo structure).

**Mitigation**:
- Document setup clearly with examples
- Include troubleshooting guide in Phase 3
- Consider managed service alternative (if Phase 3 demand is high)

### Question 3: Should adoption metrics be templatized separately?

**Issue**: adoption-metrics.yml is marked internal-only, but could customers benefit from metrics collection patterns?

**Risk**: Broader metrics infrastructure question; outside scope of #1304.

**Mitigation**:
- Deferred to Phase 3 or separate initiative (#1306?)
- Current scope: mark adoption-metrics.yml as internal-only only
- Revisit metrics templatization after agentic workflow adoption rates stabilize

### Question 4: What if memory-sweep.yml templatization fails in Phase 3?

**Issue**: If Phase 3 implementation hits friction, what's fallback?

**Risk**: Partially templatized code becomes technical debt.

**Mitigation**:
- Phase 3 decision point: if refactoring is too complex, keep internal-only
- Customer support: provide copy-paste instructions for manual adaptation
- Document escape hatch: customers can fork workflow and customize

---

## Success Criteria (Measurable)

### Phase 1 Success

1. ✅ Design document complete and reviewed (this issue)
2. ✅ All 5 memory workflows tagged with "internal-only" metadata
3. ✅ CONTRIBUTING.md updated with workflow classification
4. ✅ Agentic workflow distribution doc (#1305) clarifies memory workflows out-of-scope
5. ✅ Zero consumer confusion: no support requests asking "can I use memory-audit.yml?"

### Phase 3 Success (If Templatization Approved)

1. `@basecoat/memory-workflows` package published to npm
2. Consumer can deploy memory-sweep with <5 minutes setup (post-install)
3. At least 1 enterprise customer successfully uses templatized memory-sweep
4. Signal extractor plugins allow customization without source code changes

---

## Related Issues & Documents

### Related Issues

- **#1305**: Agentic Workflow Distribution & Consumer Agent SDK Strategy
- **#1303**: CI/CD Workflow Templatization (independent)
- **#1302**: Workflow Assessment (all-workflows-assessment.md)

### Related Files

- `.github/workflows/memory-audit.yml`
- `.github/workflows/memory-contribute.yml`
- `.github/workflows/memory-sweep.yml`
- `.github/workflows/adoption-metrics.yml`
- `.github/workflows/fork-import.yml`
- `docs/design/agentic-workflow-distribution.md` (Decision 5 cross-ref)
- `CONTRIBUTING.md` (update in Phase 1)

### Reference Docs

- [BaseCoat Memory Architecture](../memory/README.md)
- [Memory Sweep Design](../memory/sweep-design.md) (if exists)
- [Workflow Assessment](all-workflows-assessment.md)

---

**Document Status**: Design Complete  
**Last Updated**: 2024  
**Next Review**: Post-Phase-1 (if Phase 3 demand emerges)  
**Approver**: Architecture Review (pending)

<!-- markdownlint-enable MD031 MD032 MD036 MD040 MD041 -->
