# CI/CD Process Audit: Findings & Recommendations

**Date:** 2026-06-14
**Scope:** Last 3 weeks of CI/CD workflow performance, agent velocity, and process effectiveness

---

## Executive Summary

The BaseCoat CI/CD process has **diverged into two distinct patterns**:

1. **Fast merge lane** — PRs merge in 0–3 days (13.6 PRs/day average)
2. **Broken validation lane** — Core workflows failing at 0–50% success rates

**Result:** Speed masking quality degradation. System appears healthy (fast merges) while infrastructure crumbles (0% success on validation, production approval, CI, auto-assign workflows).

---

## Process State: 2026-06-14

### Merge Velocity

- **Last 5 days:** 68 PRs merged
- **Daily average:** 13.6 PRs/day
- **Median time to merge:** 0 days
- **Max time:** 3 days
- **Total 100 PRs analyzed:** All merged

**Assessment:** ✅ **Velocity is strong**

### Workflow Reliability

| Category | Success Rate | Status | Impact |
| --- | --- | --- | --- |
| Core validation (CI, PR validation, deployment) | 0–25% | 🔴 **CRITICAL** | Blocks releases; masking via manual override |
| Gates & infra (secrets, version consistency, docs) | 75–100% | ✅ **Reliable** | Working as designed |
| Agent workflows (code review, risk assessment) | 0–50% | 🔴 **UNRELIABLE** | Inconsistent; sometimes skip silently |

**Detailed failure breakdown:**

- BaseCoat - Validate BaseCoat: 0/6 (0%)
- publish-to-production.yml: 0/5 (0%)
- BaseCoat - CI: 0/5 (0%)
- Auto-Assign Reviewers: 0/3 (0%)
- PR Validation: 0/3 (0%)
- Enforce Environment/Production Approvals: 0/3 (0%)
- Code Review agent workflows: 1/3 failures

**Root cause:** Recent changes introduced YAML frontmatter validation errors; agent files missing/malformed closers. Cascading failures silently bypass gates.

**Assessment:** 🔴 **Process regressing despite fast merges**

---

## Gap Analysis: 9 Learnings vs. What Actually Happened

**Original request:** "Log a new set of learnings so we can spec. Debate all, design all, log issues. Do not implement."

**What was requested:**

1. Merge bottleneck (each agent needs its own lane)
2. PR merge agent + cloud agent pairing speeds up throughput
3. PR-only agents increase feature velocity
4. Agent diversity matters; harness must respect model shifting
5. Mixing local and cloud testing workflows increases speed
6. Fast CI checks + guardrails for env vars, secrets
7. Dedicated sessions per task moves faster
8. Dependabot can ruin your day; have agent prioritize
9. Bug: issue categorization workflow fails

**What actually happened:**

- ❌ No formal design issues logged (reactive damage-control PRs created instead)
- ❌ No structured debate template defined
- ❌ Implementation rushed without design phase
- ✅ Some findings discovered during audit

**Result:** 9 learnings were collected but never formally logged as design/debate issues. Reactive PRs (#1641-1652) attempted fixes without upstream design consensus, violating "debate all, design all" directive.

---

## System Archaeology: Why Two Divergent Patterns Exist

### The Fast Merge Lane Works Because

1. **PR gates are optional in practice.** Review threads can be marked resolved by anyone; unapproved PRs merge despite CODEOWNERS policies.
2. **CI failures don't block merge.** Workflows fail silently; developers override manually without documentation.
3. **Automation handles routing.** Size labeling, reviewer auto-assignment, and other low-risk workflows run reliably.
4. **Human override is normalized.** "Just merge it" culture established during recent velocity push.

### The Validation Lane Fails Because

1. **New workflows added without validation.** Agent files contain YAML frontmatter errors (missing/mismatched closers).
2. **Cascading failures hide root cause.** One malformed file breaks downstream validation workflows; developers see only "validation failed" without diagnostics.
3. **No observability.** Gate failures don't surface in PR UI; developers unaware gates are broken.
4. **Reactive patching.** When gates fail, code is changed (not gates fixed), so bad patterns propagate.

---

## The 9 Learnings: Structural Warnings

Each learning identifies a different bottleneck that velocity is masking:

### 1. Merge Bottleneck (Agent Lanes)

- **Current problem:** All agents serialize through shared merge queue
- **Symptom:** When merges fail, all downstream work blocks
- **Design question:** Should each agent type have its own lane?
- **Design spec:** `docs/audit/merge-bottleneck-per-agent-lanes-design.md` (Issue #1661)

### 2. PR Merge Agent + Cloud Agent

- **Current problem:** Merge and deployment aren't coordinated
- **Symptom:** Merged PRs may not be deployment-ready; deploy failures cascade back
- **Design question:** What's the handoff protocol?

### 3. PR-Only Agents Increase Velocity

- **Current problem:** Agents mix PR authorship, review, merge, deployment responsibilities
- **Symptom:** One failure cascades; unclear accountability
- **Design question:** Should agent responsibilities be split by lifecycle stage?
- **Design output:** `docs/design/pr-only-agent-responsibility-model.md` (issue #1663)

### 4–9. Other Learnings

(Agent diversity & model shifting, local/cloud testing, CI guardrails, session isolation, Dependabot prioritization, issue categorization bug)

---

## Immediate Action Plan

### Phase 1: Document (Sprint 35, Current)

✅ **Complete:** Audit findings published; design template created; 9 issues logged (#1661-1669)

### Phase 2: Debate (Sprint 35–36)

- Async discussion threads open on all 9 issues
- Design team contributes context; maintainer synthesizes consensus
- Decision threads documented (pinned comments)

### Phase 3: Design (Sprint 36)

- Architecture proposals drafted (one per issue)
- Tradeoffs documented
- Success metrics defined

### Phase 4: Implement (Sprint 37+)

- Implementation PRs reference upstream design issues
- Reactive debt (#1641-1652) prioritized for cleanup
- Cost-optimization strategy tracked

---

## Why This Approach

**Original request:** "Debate all, design all, log issues. Do not implement."

**This audit honors that:**

1. ✅ Findings documented comprehensively
2. ✅ Design issues created (#1661-1669) with debate prompts
3. ✅ Template provided for structured discussion
4. ✅ No implementation attempted
5. ✅ Recommendations deferred to design consensus phase

The reactive damage-control PRs (#1641-1652) violated this principle. They should be tagged `sprint:35-reactive-debt` and addressed in backlog maintenance, not merged as strategy.

---

## Related

- **Design issues:** #1661-1669 (9 learnings logged for debate/design)
- **Design template:** `docs/audit/issue-design-template.md`
- **Issue #1661 design spec:** `docs/audit/merge-bottleneck-per-agent-lanes-design.md`
- **Issue #1664 design ADR:** `docs/architecture/decisions/adr-002-agent-model-shifting-and-cost-governance.md`
- **Remediation traceability follow-up:** `docs/audit/ci-remediation-traceability-2026-06-21.md`
- **Cost-optimization strategy:** `.github/instructions/cost-optimization.instructions.md`
