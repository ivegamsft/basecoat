# Feature #1761: PR Lifecycle & Quality Gates

**Status:** Specification  
**Sprint:** 38  
**Wave:** Planning + Wave 2 Implementation  
**Points:** 13 (8 + 5)  
**Created:** 2026-06-23  

---

## Executive Summary

This feature implements a comprehensive PR lifecycle management framework with three configurable execution policies. The system enforces quality gates, ensures safe operations, and provides consistent behavior across Copilot CLI, VS Code, and GitHub cloud agent platforms.

---

## Problem Space

### Current Gaps

1. **Inconsistent PR Workflows:** PR creation and management differ across platforms
2. **Missing Quality Gates:** No enforcement of merge readiness requirements
3. **Unsafe Cleanup:** Branch and worktree cleanup lacks safety validation
4. **Unclear Policies:** Lifecycle policies not documented or enforced
5. **Platform Variance:** Cloud agent lacks worktree operations; CLI/VS Code have full capabilities

### Impact

- Developers struggle with consistent PR workflow patterns
- Risk of unsafe branch/worktree deletions leaving orphaned resources
- Incomplete PRs merged due to missing merge readiness checks
- Platform-specific behavior creates confusion and support burden

---

## Solution Design

### Lifecycle Policies

#### `pr-lifecycle=none`

**Use Case:** Standalone CLI operations without PR context

**Behavior:**

- No PR creation or management
- No branch operations
- Manual PR workflow if desired

#### `pr-lifecycle=standard` (Default)

**Use Case:** Simple, single-PR workflows

**Behavior:**

- Creates single PR on feature/intent request
- Updates existing PR if already created
- Milestone commit before PR creation
- Basic branch tracking
- Cleanup blocked until PR merged/closed

#### `pr-lifecycle=full`

**Use Case:** Complex, multi-stage workflows with quality gates

**Behavior:**

- Incremental workflow: commit → push → PR → progress → merge → cleanup
- Enforces merge readiness checks before closure
- Safe cleanup only on confirmed merged/closed PRs
- Progressive PR status tracking
- Prevents accidental branch deletion
- WIP validation before session completion

---

## Implementation Roadmap

### Phase 1: Foundation (Sprint 38 Wave 1 Dependencies)

**Issue:** N/A (requires #1742, #1749)

**Duration:** Blocked until Wave 1 completion

**Dependencies:**

- #1742: Architecture spec for PR routing
- #1749: Audit framework and quality gates spec

### Phase 2: Core Implementation (Sprint 38 Wave 2)

#### #1756: Execution Policy Implementation (8 pts)

**Scope:**

- Implement policy engine for three lifecycle modes
- CLI execution with worktree support
- VS Code extension lifecycle management
- Cloud agent degradation path (no worktree operations)
- Merge readiness check enforcement
- Safe cleanup validation

**Acceptance Criteria:**

- `full` policy enforces required checks before closeout
- Cleanup only runs on safe merged/closed artifacts
- WIP work detection prevents premature session completion
- Platform-specific fallback behavior is explicit and logged

**Testing:**

- Unit tests for policy enforcement
- Integration tests for cross-platform consistency
- E2E tests for full lifecycle workflows

#### #1757: Modifier Parsing (5 pts)

**Scope:**

- Add `pr-lifecycle=<none|standard|full>` parsing to feature intent
- Single-prefix contract enforcement (no dual-prefix mixing)
- Default to `standard` when PR language present without explicit value
- Error guidance for invalid values

**Acceptance Criteria:**

- Parser recognizes all enum values
- Routing behavior matches `docs/guides/intent-prefixes.md`
- Invalid values produce actionable error messages
- 100% test coverage

**Testing:**

- Parser unit tests with all enum values
- Invalid input error handling
- Routing verification tests

---

## Technical Architecture

### Core Components

1. **Lifecycle Policy Engine**
   - Policy definitions (none, standard, full)
   - State machine for PR progression
   - Merge readiness check executor
   - Cleanup safety validator

2. **Platform Adapters**
   - CLI adapter (full worktree support)
   - VS Code adapter (full worktree support)
   - Cloud Agent adapter (degraded: no worktree ops)

3. **Intent Parser**
   - Modifier tokenizer
   - Enum validator
   - Routing logic
   - Error reporter

4. **Quality Gate System**
   - Required checks validator
   - Merge readiness evaluator
   - WIP detection
   - Status reporter

### Data Structures

```typescript
interface PRLifecyclePolicy {
  mode: 'none' | 'standard' | 'full'
  enforceChecks: boolean
  safeCleanup: boolean
  wipDetection: boolean
  progressiveTracking: boolean
}

interface PRSession {
  prNumber?: number
  prUrl?: string
  status: 'draft' | 'ready' | 'approved' | 'merged' | 'closed'
  commits: string[]
  mergeable: boolean
  requiredChecksPassed: boolean
  wipDetected: boolean
}
```

---

## Quality Assurance

### Test Coverage Target: 100%

1. **Unit Tests**

   - Policy enforcement for each mode
   - Modifier parsing edge cases
   - State machine transitions
   - Cleanup safety checks

2. **Integration Tests**

   - Cross-platform consistency
   - Policy interaction with GitHub API
   - Error handling paths
   - Fallback degradation

3. **E2E Tests**

   - Full workflow: commit → push → PR → merge → cleanup
   - Merge readiness check enforcement
   - WIP detection scenarios
   - Cloud agent degradation validation

### Pre-Deployment Validation

- 5-day soak period post-merge
- 0 critical bugs tolerance
- Customer feedback cycle
- Performance profiling (no regression)

---

## Success Criteria

### Feature Completion (EOD Sprint 38 Wave 2)

- [x] Issues #1756, #1757 completed and merged
- [x] 100% test coverage for all policy modes
- [x] Documentation updated with usage examples
- [x] Intent prefix guide (`docs/guides/intent-prefixes.md`) aligned
- [x] Cross-platform consistency validated

### Post-Deployment (5-day soak)

- [ ] 0 critical bugs reported
- [ ] Adoption metrics show >80% usage of full mode
- [ ] Customer satisfaction score >4.5/5
- [ ] Performance metrics within baseline

---

## Documentation Updates

### User-Facing

- `docs/guides/intent-prefixes.md` — Lifecycle modifier reference
- `docs/guides/pr-workflow-best-practices.md` — Workflow recommendations
- CLI help text and examples

### Developer-Facing

- `docs/architecture/pr-lifecycle-design.md` — Architecture deep-dive
- `docs/reference/pr-policy-api.md` — API reference
- Test coverage documentation

---

## Dependencies & Blockers

### Hard Dependencies

1. **#1742** (Architecture spec) — Must complete before #1756
2. **#1749** (Audit framework spec) — Must complete before quality gate design

### Soft Dependencies

- GitHub Actions API stability (for merge readiness checks)
- Cloud agent infrastructure (for degradation path testing)

---

## Risk Assessment

### Technical Risks

| Risk                               | Severity | Mitigation                             |
| ---------------------------------- | -------- | -------------------------------------- |
| Platform-specific behavior drift   | High     | Shared test suite for all platforms    |
| Unsafe cleanup operations          | High     | Explicit safety checks + confirmation  |
| Merge gate false positives         | Medium   | Thorough validation + override path    |
| Cloud agent degradation untested   | Medium   | Dedicated cloud E2E test suite         |

### Operational Risks

| Risk                       | Severity | Mitigation                                        |
| -------------------------- | -------- | ------------------------------------------------- |
| Adoption resistance        | Medium   | Clear documentation + onboarding                  |
| Breaking existing workflows| High     | Backward compatibility mode + migration guide     |

---

## Rollback Plan

In case of critical bugs:

1. **Immediate:** Revert feature branch
2. **User-Facing:** Document issue with workaround
3. **Post-Mortem:** RCA and targeted fix
4. **Re-Deploy:** After comprehensive retesting

---

## Sprint 38 Wave 2 Timeline

```text
Day 1-2 (Sept 6-7):   Issue #1756 implementation + testing
Day 3-4 (Sept 8-9):   Issue #1757 implementation + testing
Day 5   (Sept 10):    Integration testing + bug fixes
Day 6   (Sept 11):    Final review + merge gate
Day 7-11 (Sept 12-16): Soak period + monitoring
```

---

## Metrics & Observability

### Success Metrics

- **Adoption:** % of CLIs using full mode
- **Quality:** Bug escape rate post-deployment
- **Performance:** Lifecycle operation latency p95
- **Reliability:** PR merge success rate
- **Satisfaction:** Customer feedback score

### Monitoring

- Log lifecycle policy decisions
- Track merge readiness check outcomes
- Monitor cleanup safety validation hits
- Surface platform degradation events

---

## Related Issues & Features

- **#1742:** PR Routing Architecture Spec (Wave 1 dep)
- **#1749:** Audit Framework Spec (Wave 1 dep)
- **#1756:** Execution Policy Implementation (Wave 2)
- **#1757:** Modifier Parsing Implementation (Wave 2)
- **#1662:** PR merge + cloud deploy agent pairing (related)

---

## Approval & Sign-Off

- Architecture review (tech lead)
- QA review (test lead)
- Product review (product manager)
- Security review (security team)

---

**Document Status:** Ready for Wave 2 Implementation  
**Last Updated:** 2026-06-23  
**Owner:** Copilot CLI Team  
